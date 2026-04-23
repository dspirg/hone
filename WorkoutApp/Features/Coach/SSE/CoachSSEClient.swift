import Foundation
import Supabase

// MARK: - SSE Event Types
// Events yielded by CoachSSEClient during coach chat streaming.
// The [ACTION] event arrives before [DONE] and carries plan modification metadata.
enum CoachSSEEvent: Sendable {
    case token(String)                        // partial prose token from GPT-4o mini
    case action(CoachResponseEnvelope)        // [ACTION]{...} metadata event before [DONE]
    case completed                            // [DONE] received — stream closed cleanly
}

// MARK: - SSE Errors
enum CoachSSEError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case invalidURL
    case streamFailed(statusCode: Int)
    case decodingFailed(underlying: Error)
    case networkError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not authenticated -- no valid session"
        case .invalidURL: return "Invalid Edge Function URL"
        case .streamFailed(let code): return "Stream failed with HTTP \(code)"
        case .decodingFailed(let err): return "Coach response decoding failed: \(err.localizedDescription)"
        case .networkError(let err): return err.localizedDescription
        }
    }
}

// MARK: - SSE Client
// Streams AI coach chat responses from the Supabase Edge Function.
//
// CRITICAL: Uses manual URLRequest with Bearer auth header — NOT supabase.functions.invokeWithStreamedResponse.
// The Supabase Swift SDK issue #634 causes the streaming path to drop the JWT Authorization header,
// resulting in unauthenticated requests that are rejected by the Edge Function.
//
// Security: T-05-02 — JWT from supabase.auth.session is sent on every request.
// The apikey header is also required for Supabase Edge Function routing.
//
// SSE Protocol:
// - data: <partial token>  → yields .token(String)
// - data: [ACTION]{...}   → yields .action(CoachResponseEnvelope) — arrives BEFORE [DONE]
// - data: [DONE]          → yields .completed — stream closed
final class CoachSSEClient: Sendable {
    private let supabaseURL: String
    private let supabaseAnonKey: String

    init() {
        // Read SUPABASE_URL from Info.plist (set via xcconfig in Phase 1)
        self.supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        self.supabaseAnonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    }

    /// Streams coach chat response tokens from the Edge Function.
    ///
    /// Returns an AsyncThrowingStream yielding:
    /// - `.token(String)` for each partial prose token during streaming
    /// - `.action(CoachResponseEnvelope)` when an [ACTION]{...} envelope is received
    /// - `.completed` when [DONE] is received (stream closes cleanly)
    ///
    /// CRITICAL: Uses manual URLRequest, NOT supabase.functions.invokeWithStreamedResponse.
    /// The SDK streaming path drops the JWT auth header (issue #634).
    func streamChat(payload: ChatPayload) -> AsyncThrowingStream<CoachSSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // 1. Get session token — throws if no valid session exists
                    let session: Session
                    do {
                        session = try await supabase.auth.session
                    } catch {
                        continuation.finish(throwing: CoachSSEError.notAuthenticated)
                        return
                    }
                    let accessToken = session.accessToken

                    // 2. Build manual URLRequest — CRITICAL: manual auth header bypasses SDK bug #634
                    guard let url = URL(string: "\(supabaseURL)/functions/v1/coach-chat") else {
                        continuation.finish(throwing: CoachSSEError.invalidURL)
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    // CRITICAL: Manual auth header -- SDK streaming path drops this (issue #634)
                    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    // apikey header required by Supabase Edge Function routing even when Authorization is present
                    request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
                    request.httpBody = try JSONEncoder().encode(payload)

                    // 3. Open byte stream via URLSession async bytes API (iOS 15+)
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

                    // Check HTTP status before processing the stream
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode != 200 {
                        continuation.finish(throwing: CoachSSEError.streamFailed(statusCode: httpResponse.statusCode))
                        return
                    }

                    // 4. Parse SSE lines
                    for try await line in asyncBytes.lines {
                        // SSE format: meaningful lines start with "data: "
                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6))

                        // CRITICAL: [ACTION] check MUST come BEFORE [DONE] check.
                        // [ACTION] arrives first as plan modification metadata, then [DONE] closes the stream.
                        if data.hasPrefix("[ACTION]") {
                            let jsonString = String(data.dropFirst(8))
                            if let jsonData = jsonString.data(using: .utf8),
                               let envelope = try? JSONDecoder().decode(CoachResponseEnvelope.self, from: jsonData) {
                                continuation.yield(.action(envelope))
                            }
                            continue
                        }

                        // [DONE] signals stream completion
                        if data == "[DONE]" {
                            continuation.yield(.completed)
                            break
                        }

                        // Parse OpenAI streaming chunk to extract content delta.
                        // Each chunk is a ChatCompletion delta JSON object.
                        if let chunkData = data.data(using: .utf8),
                           let chunk = try? JSONSerialization.jsonObject(with: chunkData) as? [String: Any],
                           let choices = chunk["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            continuation.yield(.token(content))
                        }
                    }

                    continuation.finish()
                } catch let error as CoachSSEError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: CoachSSEError.networkError(underlying: error))
                }
            }
        }
    }
}
