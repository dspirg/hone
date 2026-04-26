# Phase 5: AI Coach Chat - Pattern Map

**Mapped:** 2026-04-23
**Files analyzed:** 12 new/modified files
**Analogs found:** 11 / 12

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `WorkoutApp/Features/Coach/CoachView.swift` | component | request-response | `WorkoutApp/Features/Main/Tabs/CoachView.swift` + `WorkoutApp/Features/PlanPreview/PlanPreviewView.swift` | role-match |
| `WorkoutApp/Features/Coach/CoachViewModel.swift` | service/viewmodel | streaming + CRUD | `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` | exact |
| `WorkoutApp/Features/Coach/SSE/CoachSSEClient.swift` | service | streaming | `WorkoutApp/Features/PlanPreview/SSE/PlanSSEClient.swift` | exact |
| `WorkoutApp/Features/Coach/Components/ChatBubbleView.swift` | component | request-response | `WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift` | role-match |
| `WorkoutApp/Features/Coach/Components/ChatInputBar.swift` | component | request-response | `WorkoutApp/Features/Onboarding/Cards/InjuriesCardView.swift` | role-match |
| `WorkoutApp/Features/Coach/Components/PlanModificationCard.swift` | component | request-response | `WorkoutApp/Features/PlanPreview/Components/WorkoutDayCardView.swift` | role-match |
| `WorkoutApp/Features/Coach/Components/StreamingCursorView.swift` | component | streaming | `WorkoutApp/Features/PlanPreview/PlanGenerationLoadingView.swift` | role-match |
| `WorkoutApp/Features/Coach/Components/OfflineBannerView.swift` | component | request-response | `WorkoutApp/Core/Sync/SessionSyncService.swift` (pattern) | role-match |
| `WorkoutApp/Features/Coach/Components/ChatDateHeader.swift` | component | transform | none close | no-analog |
| `supabase/functions/coach-chat/index.ts` | service | streaming | `supabase/functions/generate-plan/index.ts` | exact |
| `WorkoutApp/Core/Data/WorkoutApp.xcdatamodeld` (modify) | model | CRUD | `WorkoutApp/Core/Data/WorkoutApp.xcdatamodeld` (existing) | exact |
| `WorkoutAppTests/CoachViewModelTests.swift` | test | — | `WorkoutAppTests/PlanPreviewViewModelTests.swift` | exact |
| `WorkoutAppTests/CoachSSEClientTests.swift` | test | — | `WorkoutAppTests/SessionSyncServiceTests.swift` | role-match |

---

## Pattern Assignments

### `WorkoutApp/Features/Coach/SSE/CoachSSEClient.swift` (service, streaming)

**Analog:** `WorkoutApp/Features/PlanPreview/SSE/PlanSSEClient.swift`

This file is the highest-fidelity copy in this phase. The only changes from the analog are: (1) the endpoint URL changes from `generate-plan` to `coach-chat`, (2) the payload type changes from `UserProfile` to `ChatPayload`, (3) the event enum gains a third case `.action(CoachResponseEnvelope)` detected when the data line starts with `[ACTION]`.

**Imports pattern** (lines 1-3):
```swift
import Foundation
import Supabase
```

**Event enum pattern** (lines 4-10 of analog — adapt for coach):
```swift
// New enum for CoachSSEClient — extends the PlanSSEEvent pattern with .action case
enum CoachSSEEvent: Sendable {
    case token(String)                        // partial prose token from GPT-4o mini
    case action(CoachResponseEnvelope)        // [ACTION]{...} metadata event before [DONE]
    case completed                            // [DONE] received — stream closed cleanly
}

struct CoachResponseEnvelope: Decodable, Sendable {
    let action: String                        // "chat" | "modify_plan" | "execute_modify"
    let planDelta: WorkoutPlan?               // Non-nil when action == "execute_modify"

    enum CodingKeys: String, CodingKey {
        case action
        case planDelta = "plan_delta"
    }
}
```

**Error enum pattern** (lines 13-29 of analog — copy verbatim, rename prefix):
```swift
enum CoachSSEError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case invalidURL
    case streamFailed(statusCode: Int)
    case decodingFailed(underlying: Error)
    case networkError(underlying: Error)
    // errorDescription pattern is identical to PlanSSEError
}
```

**Core streaming pattern** (lines 40-138 of analog — the entire `streamPlan` body is the template):

Copy `PlanSSEClient.streamPlan(profile:)` verbatim, renaming to `streamChat(payload:)`. Change these three lines only:
```swift
// Line 76 analog — change endpoint:
guard let url = URL(string: "\(supabaseURL)/functions/v1/coach-chat") else { ... }

// Line 88 analog — change payload type:
request.httpBody = try JSONEncoder().encode(payload)  // payload: ChatPayload

// Lines 104-127 analog — extend the SSE line parser with [ACTION] detection:
for try await line in asyncBytes.lines {
    guard line.hasPrefix("data: ") else { continue }
    let data = String(line.dropFirst(6))

    // [ACTION] event arrives before [DONE] — parse envelope, yield .action
    if data.hasPrefix("[ACTION]") {
        let jsonString = String(data.dropFirst(8))
        if let jsonData = jsonString.data(using: .utf8),
           let envelope = try? JSONDecoder().decode(CoachResponseEnvelope.self, from: jsonData) {
            continuation.yield(.action(envelope))
        }
        continue
    }

    if data == "[DONE]" {
        continuation.yield(.completed)
        break
    }

    // Prose token — extract content delta (same logic as PlanSSEClient lines 119-126)
    if let chunkData = data.data(using: .utf8),
       let chunk = try? JSONSerialization.jsonObject(with: chunkData) as? [String: Any],
       let choices = chunk["choices"] as? [[String: Any]],
       let delta = choices.first?["delta"] as? [String: Any],
       let content = delta["content"] as? String {
        continuation.yield(.token(content))
    }
}
```

**Auth headers pattern** (lines 83-87 of analog — copy exactly):
```swift
// CRITICAL: Manual auth header — SDK streaming path drops this (issue #634)
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
// apikey header required by Supabase Edge Function routing
request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
```

---

### `WorkoutApp/Features/Coach/CoachViewModel.swift` (service/viewmodel, streaming + CRUD)

**Analog:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift`

**Imports pattern** (lines 1-3 of analog):
```swift
import Foundation
import Supabase
```

**Class declaration pattern** (lines 37-40 of analog):
```swift
@Observable
@MainActor
final class CoachViewModel {
    // State machine for chat
}
```

**State enum pattern** (lines 6-22 of analog — adapt for chat):
```swift
enum ChatState: Equatable {
    case idle
    case streaming(partialText: String)
    case error(String)
}
```

**isSyncing guard pattern** (from `SessionSyncService.swift` lines 31, 54, 77-78):
```swift
// Prevents concurrent Supabase sync calls (Pitfall 4 in RESEARCH.md)
private(set) var isSyncing: Bool = false

// In sync method:
guard !isSyncing else { return }
isSyncing = true
defer { isSyncing = false }
```

**NWPathMonitor pattern** (from `SessionSyncService.swift` lines 35-58):
```swift
private let monitor = NWPathMonitor()
private let monitorQueue = DispatchQueue(label: "com.workoutapp.coach-network-monitor")
private(set) var isOnline: Bool = true

func startMonitoring() {
    monitor.pathUpdateHandler = { [weak self] path in
        Task { @MainActor [weak self] in
            self?.isOnline = path.status == .satisfied
        }
    }
    monitor.start(queue: monitorQueue)
}

func stopMonitoring() {
    monitor.cancel()
}
```

**Core streaming task pattern** (lines 77-142 of analog — adapt for chat):
```swift
func sendMessage(_ text: String) {
    currentStreamTask?.cancel()
    chatState = .streaming(partialText: "")

    // Write user CDChatMessage to CoreData immediately (write-ahead)
    // ...

    currentStreamTask = Task {
        defer { chatState = .idle }
        do {
            var accumulatedText = ""
            for try await event in sseClient.streamChat(payload: buildPayload(text)) {
                if Task.isCancelled { return }
                switch event {
                case .token(let chunk):
                    accumulatedText += chunk
                    chatState = .streaming(partialText: accumulatedText)
                case .action(let envelope):
                    pendingEnvelope = envelope
                case .completed:
                    // Commit accumulated coach message to CoreData
                    // Trigger plan card if pendingEnvelope.action == "modify_plan"
                    await handleStreamCompleted(text: accumulatedText, envelope: pendingEnvelope)
                }
            }
        } catch {
            // Inline error bubble — same retry-tap pattern as generate-plan service
            chatState = .error("Something went wrong. Tap to retry.")
        }
    }
}
```

**Supabase upsert pattern** (lines 193-239 of analog — adapt for coach_messages):
```swift
// Called after streaming completes — same sequential pattern as PlanGenerationService
private func syncMessagesToSupabase(userMsg: CDChatMessage, coachMsg: CDChatMessage) async throws {
    // snake_case CodingKeys — same convention as SessionLogRow / SetLogPayload
    struct MessageRow: Encodable {
        let id: String
        let user_id: String
        let role: String
        let content: String
        let created_at: Date
        let plan_modification_json: String?
        let plan_modification_state: String?
    }
    try await supabase
        .from("coach_messages")
        .upsert([userRow, coachRow], onConflict: "id")
        .execute()
}
```

---

### `supabase/functions/coach-chat/index.ts` (service, streaming)

**Analog:** `supabase/functions/generate-plan/index.ts`

**Imports pattern** (line 11 of analog — copy verbatim):
```typescript
import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
```

**CORS preflight pattern** (lines 54-65 of analog — copy verbatim):
```typescript
if (req.method === "OPTIONS") {
    return new Response(null, {
        status: 204,
        headers: {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Authorization, Content-Type",
        },
    });
}
```

**API key guard pattern** (lines 67-77 of analog — copy verbatim):
```typescript
const openAIKey = Deno.env.get("OPENAI_API_KEY");
if (!openAIKey) {
    return new Response(
        JSON.stringify({ error: "OPENAI_API_KEY is not configured" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
    );
}
```

**Auth header validation pattern** (lines 79-89 of analog — copy verbatim):
```typescript
const authHeader = req.headers.get("Authorization");
if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return new Response(
        JSON.stringify({ error: "Unauthorized" }),
        { status: 401, headers: { "Content-Type": "application/json" } }
    );
}
```

**Input validation pattern** (lines 99-148 of analog — adapt for ChatPayload):
```typescript
// Validate and truncate user-supplied fields (same defense-in-depth as generate-plan)
const MAX_MESSAGE_LEN = 2000;
if (!payload.message || payload.message.length > MAX_MESSAGE_LEN) {
    return new Response(
        JSON.stringify({ error: "message field missing or exceeds 2000 chars" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
    );
}
const safeMessage = payload.message.slice(0, MAX_MESSAGE_LEN);
```

**planSchema reuse pattern** (lines 17-52 of analog — import for plan modification):
```typescript
// Copy planSchema from generate-plan/index.ts — used on action == "execute_modify"
// Called with GPT-4o + Structured Outputs (non-streaming), same shape as plan generation
const modifyResponse = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: { "Authorization": `Bearer ${openAIKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({
        model: "gpt-4o-2024-08-06",
        stream: false,          // modification: wait for full plan, do not stream
        response_format: {
            type: "json_schema",
            json_schema: { name: "workout_plan", strict: true, schema: planSchema },
        },
        messages: [modificationSystemMsg, modificationUserMsg],
    }),
});
```

**SSE passthrough pattern** (lines 219-227 of analog — extend with [ACTION] injection):
```typescript
// Forward the OpenAI prose stream, then inject [ACTION] event before [DONE]
// Option B from RESEARCH.md: prose tokens pass through; metadata arrives as separate event
const stream = new ReadableStream({
    async start(controller) {
        const encoder = new TextEncoder();
        // Forward all OpenAI SSE lines from openAIResponse.body
        // After the forwarding loop ends (OpenAI sent [DONE]), inject action event:
        const actionPayload = JSON.stringify({
            action: intentAction,           // "chat" | "modify_plan"
            plan_delta: planDelta ?? null,  // null for plain chat turns
        });
        controller.enqueue(encoder.encode(`data: [ACTION]${actionPayload}\n\n`));
        controller.enqueue(encoder.encode("data: [DONE]\n\n"));
        controller.close();
    },
});

return new Response(stream, {
    headers: {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
        "Access-Control-Allow-Origin": "*",
    },
});
```

**Error response pattern** (lines 203-217 of analog — copy verbatim, change label):
```typescript
if (!openAIResponse.ok) {
    const errorBody = await openAIResponse.text();
    console.error(`coach-chat: OpenAI API error ${openAIResponse.status}: ${errorBody}`);
    return new Response(
        JSON.stringify({ error: "OpenAI API error", status: openAIResponse.status, detail: errorBody }),
        { status: openAIResponse.status, headers: { "Content-Type": "application/json" } }
    );
}
```

---

### `WorkoutApp/Features/Coach/CoachView.swift` (component, request-response)

**Analog:** `WorkoutApp/Features/Main/Tabs/CoachView.swift` (shell to replace) + `WorkoutApp/Features/PlanPreview/PlanGenerationLoadingView.swift` (animation/error pattern)

**Imports and @Environment pattern** (AppState.swift line 8-10 / conventional project pattern):
```swift
import SwiftUI

struct CoachView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = CoachViewModel()

    var body: some View {
        // Replace the empty VStack shell from the current CoachView.swift
    }
}
```

**Offline banner pattern** (from RESEARCH.md Pattern inline + SessionSyncService.swift pattern):
```swift
// Banner sits above the input bar, slides in/out with .transition
if !viewModel.isOnline {
    Text("No connection — coach unavailable")
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .transition(.move(edge: .top).combined(with: .opacity))
}
```

**Error state pattern** (from `PlanGenerationLoadingView.swift` lines 120-164 — adapt for inline bubble):
```swift
// Error bubble in chat thread — tap-to-retry, not a full-screen overlay
Button(action: { viewModel.retry() }) {
    HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle")
            .foregroundStyle(.secondary)
        Text("Something went wrong. Tap to retry.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding(12)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 12))
}
```

---

### `WorkoutApp/Features/Coach/Components/StreamingCursorView.swift` (component, streaming)

**Analog:** `WorkoutApp/Features/PlanPreview/PlanGenerationLoadingView.swift` (pulsing animation pattern)

**Animation pattern** (lines 108-115 of analog — simplified for cursor):
```swift
// Pulsing rings in analog use .linear(duration:).repeatForever(autoreverses: false)
// Cursor uses .easeInOut to mirror ChatGPT blinking cursor convention (RESEARCH.md)
struct StreamingCursorView: View {
    @State private var opacity: Double = 1.0
    var body: some View {
        Text("|")
            .fontWeight(.thin)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever()) {
                    opacity = 0.1
                }
            }
    }
}
```

---

### `WorkoutApp/Features/Coach/Components/ChatInputBar.swift` (component, request-response)

**Analog:** `WorkoutApp/Features/Onboarding/Cards/InjuriesCardView.swift` (TextField usage pattern)

**Auto-expanding input pattern** (D-34 — standard iOS 16+ pattern):
```swift
TextField("Ask your coach...", text: $messageText, axis: .vertical)
    .lineLimit(1...4)
    .padding(12)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .disabled(viewModel.isStreaming)

// Send button — disabled during streaming (D-03)
Button(action: { viewModel.sendMessage(messageText) }) {
    Image(systemName: "arrow.up.circle.fill")
        .font(.system(size: 32))
        .foregroundStyle(messageText.isEmpty || viewModel.isStreaming ? Color(.systemGray4) : Color("AccentColor"))
}
.disabled(messageText.isEmpty || viewModel.isStreaming || !viewModel.isOnline)
```

---

### `WorkoutApp/Features/Coach/Components/PlanModificationCard.swift` (component, request-response)

**Analog:** `WorkoutApp/Features/PlanPreview/Components/WorkoutDayCardView.swift` (card layout pattern)

**Card layout pattern** (WorkoutDayCardView structure — adapt for before/after diff):
```swift
// Card sits below the coach message bubble — rounded rect, system background
VStack(alignment: .leading, spacing: 12) {
    // Before/after diff rows
    // Confirm + Dismiss buttons

    HStack(spacing: 12) {
        Button("Dismiss") { viewModel.dismissModification(messageId: message.id) }
            .buttonStyle(.bordered)

        Button("Confirm") { viewModel.confirmModification(messageId: message.id) }
            .buttonStyle(.borderedProminent)
            .tint(Color("AccentColor"))
    }
}
.padding(16)
.background(Color(.systemBackground))
.clipShape(RoundedRectangle(cornerRadius: 16))
.shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
```

**Confirmed state animation** (from `PlanGenerationLoadingView.swift` `.transition(.opacity)` pattern):
```swift
// After confirm, card animates to compact "Plan updated" state
// Use .animation(.easeInOut, value: message.planModificationState)
if message.planModificationState == "confirmed" {
    HStack(spacing: 6) {
        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        Text("Plan updated").font(.subheadline.weight(.medium))
    }
    .transition(.opacity)
}
```

---

### `WorkoutApp/Core/Data/WorkoutApp.xcdatamodeld` (modify — add CDChatMessage entity)

**Analog:** Existing `CDSessionLog` entity in the same model file (write-ahead + syncedToSupabase pattern).

**Entity schema to add** (from RESEARCH.md Pattern 5 — validated against CDSessionLog pattern):
```xml
<entity name="CDChatMessage" representedClassName="CDChatMessage"
        syncable="YES" codeGenerationType="class">
    <attribute name="id" attributeType="UUID" usesScalarValueType="NO"/>
    <attribute name="userId" attributeType="String"/>
    <attribute name="role" attributeType="String"/>
    <!-- "user" or "coach" — drives bubble alignment in ChatBubbleView -->
    <attribute name="content" attributeType="String"/>
    <attribute name="createdAt" attributeType="Date" usesScalarValueType="NO"/>
    <attribute name="syncedToSupabase" attributeType="Boolean"
               defaultValueString="NO" usesScalarValueType="YES"/>
    <!-- Matches CDSessionLog.syncedToSupabase pattern — same write-ahead convention -->
    <attribute name="planModificationJSON" optional="YES" attributeType="String"/>
    <attribute name="planModificationState" optional="YES" attributeType="String"/>
    <!-- "pending" | "confirmed" | "dismissed" -->
</entity>
```

The CoreData repository for chat messages follows the exact same `@MainActor final class` with `NSManagedObjectContext` injection pattern as `SessionRepository.swift` (lines 21-31).

---

### `WorkoutAppTests/CoachViewModelTests.swift` (test)

**Analog:** `WorkoutAppTests/PlanPreviewViewModelTests.swift`

**Test class pattern** (lines 10-48 of analog — copy structure):
```swift
import XCTest
@testable import WorkoutApp

// MARK: - CoachViewModelTests
// Unit tests for CoachViewModel state machine.
// Requirements: CHAT-01, CHAT-02, CHAT-03

@MainActor
final class CoachViewModelTests: XCTestCase {

    // Helper: create fresh viewModel for each test
    func makeViewModel() -> CoachViewModel {
        CoachViewModel()
    }

    // MARK: - Tests

    func testInitialStateIsIdle() { ... }
    func testOfflineDisablesSend() { ... }
    func testModifyPlanActionTriggersCard() { ... }
    func testConfirmPlanModification() { ... }
    func testDismissPlanModification() { ... }
    func testSystemPromptPayloadContents() { ... }
    func testMessageHistoryCap() { ... }
}
```

**State mutation test pattern** (lines 65-102 of analog — direct state assignment):
```swift
// Tests directly set @Observable state — same pattern as PlanPreviewViewModelTests
func testIsStreamingWhenStreaming() {
    let vm = makeViewModel()
    // Simulate streaming state start
    vm.chatState = .streaming(partialText: "Hello")
    XCTAssertTrue(vm.isStreaming)
    XCTAssertFalse(vm.canSend)  // D-03: send disabled during streaming
}
```

---

### `WorkoutAppTests/CoachSSEClientTests.swift` (test)

**Analog:** `WorkoutAppTests/SessionSyncServiceTests.swift`

**Test class pattern** (same `@MainActor final class XCTestCase` structure):
```swift
import XCTest
@testable import WorkoutApp

@MainActor
final class CoachSSEClientTests: XCTestCase {
    // Tests for SSE line parsing — mock URLSession responses
    // Tests for [ACTION] prefix detection
    // Tests for [DONE] stream completion
    // Tests for HTTP error status codes (streamFailed)
    // Tests for missing auth token (notAuthenticated)
}
```

---

## Shared Patterns

### @Observable @MainActor ViewModel
**Source:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` lines 37-40 and `WorkoutApp/Features/Session/SessionViewModel.swift` lines 19-22
**Apply to:** `CoachViewModel.swift`
```swift
@Observable
@MainActor
final class CoachViewModel {
    // State as stored properties — @Observable macro generates access tracking
    // No @Published needed; SwiftUI reads directly from @Observable properties
}
```

### Manual URLRequest with Dual Auth Headers (Supabase SDK Bug #634)
**Source:** `WorkoutApp/Features/PlanPreview/SSE/PlanSSEClient.swift` lines 83-87
**Apply to:** `CoachSSEClient.swift` — every request to the Edge Function
```swift
// CRITICAL: Manual auth header — SDK streaming path drops this (issue #634)
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
// apikey header required by Supabase Edge Function routing
request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
```

### AsyncThrowingStream Task Cancellation Guard
**Source:** `WorkoutApp/Features/PlanPreview/PlanGenerationService.swift` lines 85-87 and 123-124
**Apply to:** `CoachViewModel.sendMessage()` streaming loop
```swift
for try await event in sseClient.streamChat(payload: payload) {
    if Task.isCancelled { return }
    // process event
}
// In catch:
if Task.isCancelled { return }
```

### isSyncing Guard for Concurrent Supabase Calls
**Source:** `WorkoutApp/Core/Sync/SessionSyncService.swift` lines 31, 54, 77-78
**Apply to:** `CoachViewModel.syncMessagesToSupabase()` — prevents Pitfall 4 from RESEARCH.md
```swift
private(set) var isSyncing: Bool = false

// At start of sync method:
guard !isSyncing else { return }
isSyncing = true
defer { isSyncing = false }
```

### NWPathMonitor on Background Queue
**Source:** `WorkoutApp/Core/Sync/SessionSyncService.swift` lines 35-58
**Apply to:** `CoachViewModel.swift` for `isOnline` published state
```swift
private let monitor = NWPathMonitor()
private let monitorQueue = DispatchQueue(label: "com.workoutapp.coach-network-monitor")

func startMonitoring() {
    monitor.pathUpdateHandler = { [weak self] path in
        Task { @MainActor [weak self] in
            self?.isOnline = path.status == .satisfied
        }
    }
    monitor.start(queue: monitorQueue)  // NEVER start on .main
}
```

### Edge Function: Auth Validation + Input Sanitization
**Source:** `supabase/functions/generate-plan/index.ts` lines 79-148
**Apply to:** `supabase/functions/coach-chat/index.ts`

The entire validation block (CORS → API key guard → Bearer token check → payload validation → length truncation) is copied verbatim and the field names are updated for `ChatPayload` fields.

### Supabase Encodable Row with snake_case CodingKeys
**Source:** `WorkoutApp/Core/Sync/SessionSyncService.swift` lines 178-225 (`SessionLogRow`, `SetLogPayload`)
**Apply to:** `CoachViewModel` sync path — `MessageRow` struct for `coach_messages` upsert
```swift
private struct MessageRow: Encodable {
    let id: String
    let userId: String
    let role: String
    let content: String
    let createdAt: Date
    let syncedToSupabase: Bool
    let planModificationJSON: String?
    let planModificationState: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case role
        case content
        case createdAt = "created_at"
        case syncedToSupabase = "synced_to_supabase"
        case planModificationJSON = "plan_modification_json"
        case planModificationState = "plan_modification_state"
    }
}
```

### Config Values from Info.plist
**Source:** `WorkoutApp/Features/PlanPreview/SSE/PlanSSEClient.swift` lines 44-48
**Apply to:** `CoachSSEClient.init()`
```swift
init() {
    self.supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    self.supabaseAnonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
}
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `WorkoutApp/Features/Coach/Components/ChatDateHeader.swift` | component | transform | No date-grouped list component exists in the codebase. Use standard `RelativeDateTimeFormatter` + `Calendar.current.isDateInToday/isDateInYesterday`. Pattern is from RESEARCH.md Pattern (Code Examples section) — standard Swift Calendar API, no codebase analog needed. |

---

## Metadata

**Analog search scope:** `/WorkoutApp/**`, `/supabase/functions/**`, `/WorkoutAppTests/**`
**Files scanned:** 13 Swift files + 2 TypeScript files + 1 test file read in full
**Pattern extraction date:** 2026-04-23

**Critical warnings for planner:**
1. `CoachSSEClient` MUST use manual `URLRequest` — never `supabase.functions.invokeWithStreamedResponse` (SDK bug #634). This is the #1 pitfall and is already documented in the analog file.
2. The streaming pending message bubble MUST live outside the `ForEach(viewModel.messages)` loop to avoid `LazyVStack` recycling (Pitfall 7 in RESEARCH.md).
3. `defer { isSyncing = false }` must be set before the first `await` in any Supabase sync path to prevent concurrent duplicate writes (Pitfall 4 in RESEARCH.md).
4. The `[ACTION]` prefix in SSE line parsing must be detected BEFORE the `[DONE]` check, as both are terminal events.
5. CoreData `CDChatMessage` migration is lightweight (new entity, no relationships to existing entities) — no migration mapping model needed.
