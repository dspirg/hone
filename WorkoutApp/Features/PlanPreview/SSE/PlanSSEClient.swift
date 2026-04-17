import Foundation
import Supabase

// MARK: - SSE Event Types
// Events yielded by PlanSSEClient during plan streaming.
// PITFALL 3: Only .completed contains parseable JSON. .token events are partial chunks.
enum PlanSSEEvent: Sendable {
    case token(String)           // partial JSON token chunk from OpenAI delta
    case completed(String)       // full accumulated JSON string after [DONE]
}

// MARK: - SSE Errors
enum PlanSSEError: Error, LocalizedError, Sendable {
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
        case .decodingFailed(let err): return "Plan decoding failed: \(err.localizedDescription)"
        case .networkError(let err): return err.localizedDescription
        }
    }
}

// MARK: - SSE Client
// Streams AI-generated workout plan tokens from the Supabase Edge Function.
//
// CRITICAL: Uses manual URLRequest with Bearer auth header — NOT supabase.functions.invokeWithStreamedResponse.
// The Supabase Swift SDK issue #634 causes the streaming path to drop the JWT Authorization header,
// resulting in unauthenticated requests that are rejected by the Edge Function.
//
// Security: T-03-08 — JWT from supabase.auth.session is sent on every request.
// The apikey header is also required for Supabase Edge Function routing.
final class PlanSSEClient: Sendable {
    private let supabaseURL: String
    private let supabaseAnonKey: String

    init() {
        // Read SUPABASE_URL from Info.plist (set via xcconfig in Phase 1)
        self.supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
        self.supabaseAnonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    }

    /// Streams plan generation tokens from the Edge Function.
    ///
    /// Returns an AsyncThrowingStream yielding:
    /// - `.token(String)` for each partial JSON content delta during streaming
    /// - `.completed(String)` with the full accumulated JSON when [DONE] is received
    ///
    /// PITFALL 1: Uses manual URLRequest, NOT supabase.functions.invokeWithStreamedResponse.
    /// The SDK streaming path drops the JWT auth header (issue #634).
    ///
    /// PITFALL 3: Do NOT attempt to parse accumulated JSON as WorkoutPlan during streaming.
    /// Partial JSON is invalid until [DONE]. Only the .completed event has parseable JSON.
    func streamPlan(profile: UserProfile) -> AsyncThrowingStream<PlanSSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // 1. Get session token — throws if no valid session exists
                    let session: Session
                    do {
                        session = try await supabase.auth.session
                    } catch {
                        continuation.finish(throwing: PlanSSEError.notAuthenticated)
                        return
                    }
                    let accessToken = session.accessToken

                    // 2. Build manual URLRequest — CRITICAL: manual auth header bypasses SDK bug #634
                    guard let url = URL(string: "\(supabaseURL)/functions/v1/generate-plan") else {
                        continuation.finish(throwing: PlanSSEError.invalidURL)
                        return
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    // CRITICAL: Manual auth header -- SDK streaming path drops this (issue #634)
                    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    // apikey header required by Supabase Edge Function routing even when Authorization is present
                    request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
                    request.httpBody = try JSONEncoder().encode(profile)

                    // 3. Open byte stream via URLSession async bytes API (iOS 15+)
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

                    // Check HTTP status before processing the stream
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode != 200 {
                        continuation.finish(throwing: PlanSSEError.streamFailed(statusCode: httpResponse.statusCode))
                        return
                    }

                    // 4. Parse SSE lines -- accumulate JSON content tokens
                    // PITFALL 3: accumulatedJSON is partial during streaming; only parse after [DONE]
                    var accumulatedJSON = ""

                    for try await line in asyncBytes.lines {
                        // SSE format: meaningful lines start with "data: "
                        guard line.hasPrefix("data: ") else { continue }
                        let data = String(line.dropFirst(6))

                        // [DONE] signals stream completion -- yield complete accumulated JSON
                        if data == "[DONE]" {
                            continuation.yield(.completed(accumulatedJSON))
                            break
                        }

                        // Parse OpenAI streaming chunk to extract content delta.
                        // Each chunk is a ChatCompletion delta JSON object.
                        // We do NOT call JSONDecoder().decode(WorkoutPlan.self) here -- that happens
                        // in PlanGenerationService after receiving the .completed event.
                        if let chunkData = data.data(using: .utf8),
                           let chunk = try? JSONSerialization.jsonObject(with: chunkData) as? [String: Any],
                           let choices = chunk["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            accumulatedJSON += content
                            continuation.yield(.token(content))
                        }
                    }

                    continuation.finish()
                } catch let error as PlanSSEError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: PlanSSEError.networkError(underlying: error))
                }
            }
        }
    }
}
