# Phase 5: AI Coach Chat - Research

**Researched:** 2026-04-23
**Domain:** SwiftUI chat UI, SSE streaming, CoreData message persistence, Supabase Edge Function routing, OpenAI two-model strategy
**Confidence:** HIGH

## Summary

Phase 5 replaces the empty `CoachView` shell with a fully functional AI chat interface. The coach is reactive only (CHAT-04 proactive messages deferred to Phase 8). The three core capabilities are: (1) streaming conversational responses via a new `coach-chat` Supabase Edge Function that mirrors the `generate-plan` SSE pattern, (2) plan modification triggered by user confirmation of an inline diff card, and (3) a persistent single-thread message history backed by a new `CDChatMessage` CoreData entity with Supabase sync.

All locked decisions from CONTEXT.md are highly compatible with existing codebase patterns. The `generate-plan` Edge Function and `PlanSSEClient` provide a proven SSE template. The `SessionSyncService` NWPathMonitor pattern ports directly to offline detection. `@Observable @MainActor` MVVM is the established app pattern. The main new surface areas are: (a) the `CDChatMessage` CoreData entity design, (b) the `coach_messages` Supabase table schema, (c) the Edge Function response envelope that includes an `action` discriminator for plan modification routing, and (d) the SwiftUI auto-expanding `TextField(axis: .vertical)` chat input with `lineLimit(1...4)`.

**Primary recommendation:** Create a `coach-chat` Supabase Edge Function that uses the same SSE passthrough pattern as `generate-plan`, but adds an `action` field in the response envelope (`"chat"` vs `"modify_plan"`) detected after the stream completes, so the iOS client can route to plan modification without a second round trip.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Streaming UX**
- D-01: Token-by-token streaming — words appear as they're generated, reusing the SSE pattern from `generate-plan` Edge Function
- D-02: Always auto-scroll — chat sticks to the bottom as tokens arrive
- D-03: Input blocked during streaming — send button disabled. No interruption/cancellation in Phase 5
- D-04: Pulsing cursor at end of streaming text while tokens arrive, disappears when complete

**Plan Modification Flow**
- D-05: Coach proposes changes inline: "I'd swap X for Y — want me to update your plan?"
- D-06: Inline confirmation card with before/after diff below coach message
- D-07: All modification scopes supported: single exercise swap, multi-exercise within a day, full plan regeneration
- D-08: [Confirm] and [Dismiss] buttons on the confirmation card
- D-09: On [Confirm]: call GPT-4o with Structured Outputs to regenerate affected plan section; update `workout_plans` in Supabase and CoreData
- D-10: On [Dismiss]: coach acknowledges and continues conversation; no plan change
- D-11: After confirmation, card animates to a compact "Plan updated ✓" state and stays in chat history
- D-12: No silent modifications — user always explicitly confirms

**Model Routing**
- D-13: GPT-4o mini — all conversational turns
- D-14: GPT-4o — plan modification calls only (triggered by [Confirm] tap, Structured Outputs)
- D-15: Routing logic lives in the Supabase Edge Function: detect `action: "modify_plan"` in coach response JSON
- D-16: Both models called through existing Edge Function proxy — never directly from iOS client

**Chat History & Sync**
- D-17: Single ongoing thread per user — one persistent conversation, never reset
- D-18: Date section headers (Yesterday, Today, etc.)
- D-19: Load last 50 messages from CoreData on tab open; paginate older messages in batches of 50
- D-20: Messages sync to Supabase immediately after each exchange
- D-21: No offline message queuing — coach requires network. Offline = read-only with banner
- D-22: Old messages summarized server-side when context window approaches limit; summary injected into system prompt, raw messages pruned from context
- D-23: [+] button reserved for future use (not wired in Phase 5)

**Coach Persona & Tone**
- D-24: Direct expert personality — knowledgeable and efficient, doesn't waste words
- D-25: Response length: medium (3-5 sentences)
- D-26: Uses user's name occasionally
- D-27: Coach has visible name + icon (SF Symbol or custom icon)

**Coach Context (System Prompt)**
- D-28: Always injected per request: fitness profile + current workout plan + last 3 session summaries
- D-29: Session summaries: date, workout name, exercises completed, sets logged
- D-30: Context does not grow unbounded — only last 3 sessions, full plan, profile

**Proactive Messages (CHAT-04)**
- D-31: CHAT-04 deferred to Phase 8 — Phase 5 is reactive only

**Offline Behavior**
- D-32: Non-intrusive banner: "No connection — coach unavailable"; banner dismisses when connectivity returns

**Error States**
- D-33: Failed coach responses show inline error bubble: "Something went wrong. Tap to retry." Tap resends last message

**Input Field**
- D-34: Multi-line auto-expanding text input — single line, expands to 4 lines max. No character limit, no voice, no prompt chips

### Claude's Discretion
- Exact system prompt template and coach persona copy (guided by D-24 through D-27)
- SwiftUI chat bubble component design (user vs coach alignment, colors)
- CoreData entity for chat messages (ChatMessage entity)
- `coach_messages` Supabase table schema
- Context summarization trigger threshold (e.g., when message count > 50)
- Coach name label text and icon choice (SF Symbol selection)

### Deferred Ideas (OUT OF SCOPE)
- Voice input for coach messages
- Coach-initiated proactive messages — Phase 8 (CHAT-04)
- Multiple conversation threads / topic tagging
- Coach memory beyond last 3 sessions (long-term pattern detection) — Phase 8
- Suggested prompt chips on empty state
- Message interruption/cancellation during streaming
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CHAT-01 | User can ask the AI coach any fitness-related question at any time | SSE streaming via `coach-chat` Edge Function; conversational GPT-4o mini model routing (D-13) |
| CHAT-02 | User can modify their workout plan by talking to the AI coach in natural conversation | `action: "modify_plan"` discriminator in Edge Function response; inline confirmation card (D-05 through D-12); GPT-4o Structured Outputs on confirm (D-14) |
| CHAT-03 | AI coach has full context of user's profile, goals, and workout history when responding | System prompt injection on every request (D-28 to D-30); AppState provides profile + plan; CDSessionLog provides last 3 session summaries |
| CHAT-04 | AI coach proactively sends check-in messages based on user activity — DEFERRED | D-31: deferred to Phase 8. No implementation in Phase 5 |
</phase_requirements>

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Chat streaming (SSE) | API / Backend (Edge Function) | iOS Client (URLSession bytes) | OpenAI API key must never be on device; Edge Function proxies and forwards SSE stream |
| Message persistence | iOS Client (CoreData) | Supabase (coach_messages table) | Write-ahead to CoreData first; sync to Supabase after streaming completes |
| System prompt assembly | API / Backend (Edge Function) | — | Edge Function receives profile + plan + session summaries as payload; assembles prompt server-side to keep prompt logic out of client |
| Plan modification routing | API / Backend (Edge Function) | iOS Client (confirmation UI) | Edge Function detects intent and returns action discriminator; client shows diff card and triggers GPT-4o call on [Confirm] |
| Plan modification execution | API / Backend (Edge Function) | iOS Client (CoreData + Supabase write) | Same Edge Function, different model (GPT-4o + Structured Outputs); client applies the returned plan patch |
| Offline detection | iOS Client (NWPathMonitor) | — | Reuse SessionSyncService pattern; drives banner visibility and send-button disabled state |
| Context window management | API / Backend (Edge Function) | iOS Client (message count trigger) | Edge Function performs summarization when context grows large; iOS client triggers by sending message count |
| Auto-scroll chat | iOS Client (SwiftUI) | — | `.defaultScrollAnchor(.bottom)` + `scrollPosition` drives chat UX entirely on-device |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 16+ (project target) | Chat UI, bubbles, scroll, input | Already the project UI framework. `TextField(axis: .vertical)` with `lineLimit(1...4)` is the standard auto-expanding input pattern [VERIFIED: developer.apple.com] |
| Swift Concurrency (async/await + Actors) | Swift 6 | SSE streaming, CoreData writes, Supabase sync | Established project pattern; `AsyncThrowingStream` already used in `PlanSSEClient` [VERIFIED: codebase grep] |
| CoreData | iOS 16+ | CDChatMessage entity — local message store | Existing schema extended; matches all other persistence in this project [VERIFIED: WorkoutApp.xcdatamodeld] |
| Supabase Swift SDK | 2.x (via SPM) | `coach_messages` table upsert, auth token | Already installed project dependency [VERIFIED: codebase] |
| NWPathMonitor (Network.framework) | iOS 12+ | Offline detection for chat banner | Already used in `SessionSyncService.swift`; zero new dependencies [VERIFIED: codebase] |
| OpenAI API (custom URLSession) | GPT-4o mini / GPT-4o | Chat turns / plan modification | Project convention: custom URLSession wrapper over OpenAI REST; CLAUDE.md two-model strategy [VERIFIED: CLAUDE.md] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Deno / Supabase Edge Runtime | Supabase hosted | `coach-chat` Edge Function | New function following `generate-plan` pattern [VERIFIED: generate-plan/index.ts] |
| SF Symbols | Built-in | Coach icon, send button icon | No external dependency; `bubble.left.and.bubble.right.fill` or `figure.run` for coach persona icon |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom SSE client (AsyncThrowingStream) | URLSession websocket | SSE is already proven in PlanSSEClient; WebSocket adds bidirectional complexity not needed here |
| TextField(axis: .vertical) with lineLimit(1...4) | TextEditor | TextField auto-expands from 1 line without extra framing; TextEditor always shows full height and requires custom height calculation |
| CoreData CDChatMessage | UserDefaults or in-memory | CoreData matches all project persistence; in-memory loses chat history on app restart |
| Single `coach-chat` Edge Function | Two separate functions (chat + modify_plan) | Single function with action discriminator is simpler; routing logic stays server-side (D-15) |

**Installation:** No new packages required. All dependencies are already in the project.

**Version verification (npm proxy packages, not iOS SPM):**
- openai (npm): 6.34.0 [VERIFIED: npm view]
- supabase (npm): 2.95.0 [VERIFIED: npm view]

---

## Architecture Patterns

### System Architecture Diagram

```
User types message
        |
        v
CoachViewModel.sendMessage()
  - Builds ChatPayload: {message, profile, plan, session_summaries, message_count}
  - Saves user CDChatMessage to CoreData (immediate)
  - Sets isStreaming = true, disables send button
        |
        v
CoachSSEClient (new, mirrors PlanSSEClient)
  - Manual URLRequest with Bearer auth header (Supabase SDK bug #634)
  - POST /functions/v1/coach-chat
  - Yields AsyncThrowingStream<CoachSSEEvent>
        |
        v
[Supabase Edge Function: coach-chat]
  - Validates Bearer token
  - Assembles system prompt (profile + plan + last 3 sessions)
  - Checks: is message_count > threshold? → inject summary instead of full history
  - Routes: GPT-4o mini (conversational) or GPT-4o (plan mod on Confirm tap)
  - Returns SSE stream (text/event-stream)
  - Last event before [DONE]: JSON envelope with action discriminator
        |
        v
CoachViewModel processes stream:
  - .token events → append to pendingText → auto-scroll
  - .completed event → parse JSON envelope
        |
        +--> action == "chat": save CDChatMessage (coach), sync both to Supabase
        |
        +--> action == "modify_plan": show PlanModificationCard
                  |
                  +--> [Confirm] → POST /functions/v1/coach-chat (action=execute_modify)
                  |      → GPT-4o + Structured Outputs → plan patch JSON
                  |      → Apply to CDWorkoutPlan + Supabase workout_plans
                  |      → Card animates to "Plan updated ✓"
                  |
                  +--> [Dismiss] → send dismissal message → coach acknowledges
```

### Recommended Project Structure

```
WorkoutApp/Features/Coach/
├── CoachView.swift                    # Replace empty shell (entry point)
├── CoachViewModel.swift               # @Observable @MainActor — chat state machine
├── SSE/
│   └── CoachSSEClient.swift           # Mirrors PlanSSEClient for coach streaming
├── Components/
│   ├── ChatBubbleView.swift           # User vs coach bubble (alignment, colors)
│   ├── CoachHeaderView.swift          # Coach name + SF Symbol icon row
│   ├── ChatInputBar.swift             # TextField(axis:.vertical) + send button
│   ├── PlanModificationCard.swift     # Before/after diff card with Confirm/Dismiss
│   ├── StreamingCursorView.swift      # Pulsing cursor animation
│   ├── OfflineBannerView.swift        # Reusable — mirrors Phase 4 banner pattern
│   └── ChatDateHeader.swift          # "Today", "Yesterday", date section headers
supabase/functions/coach-chat/
└── index.ts                           # New Edge Function — SSE + action routing
WorkoutAppTests/
├── CoachViewModelTests.swift          # Unit tests for state machine
└── CoachSSEClientTests.swift          # Tests for stream parsing / error cases
```

### Pattern 1: Auto-Expanding Chat Input (D-34)
**What:** `TextField` with `axis: .vertical` and `lineLimit(1...4)` auto-expands from 1 to 4 lines as the user types, then scrolls within 4 lines. No custom height calculation needed.
**When to use:** Always — this is the locked D-34 pattern.
**Example:**
```swift
// Source: developer.apple.com/documentation/swiftui/textfield/init(_:text:prompt:axis:)
TextField("Ask your coach...", text: $messageText, axis: .vertical)
    .lineLimit(1...4)
    .padding(12)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .disabled(viewModel.isStreaming)
```

### Pattern 2: Auto-Scroll to Bottom (D-02)
**What:** `ScrollViewReader` with `scrollTo(lastMessageId, anchor: .bottom)` called inside `.onChange(of: messages)`. `defaultScrollAnchor(.bottom)` sets the initial position.
**When to use:** Called every time a new token arrives (CoachViewModel appends to pendingText) AND when streaming completes and message is committed.
**Example:**
```swift
// Source: developer.apple.com/documentation/swiftui/view/defaultscrollanchor(_:)
ScrollViewReader { proxy in
    ScrollView {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.messages) { msg in
                ChatBubbleView(message: msg)
                    .id(msg.id)
            }
            // Anchor target at bottom for streaming tokens
            Color.clear.frame(height: 1).id("bottom")
        }
    }
    .defaultScrollAnchor(.bottom)
    .onChange(of: viewModel.streamingToken) { _ in
        proxy.scrollTo("bottom", anchor: .bottom)
    }
}
```

### Pattern 3: CoachSSEClient (Mirrors PlanSSEClient)
**What:** `AsyncThrowingStream<CoachSSEEvent, Error>` using manual `URLRequest` with `Bearer` auth header. Yields `.token(String)` and `.completed(CoachResponseEnvelope)`.
**When to use:** Every coach message send. Must NOT use `supabase.functions.invokeWithStreamedResponse` (SDK bug #634).
**Example:**
```swift
// Source: WorkoutApp/Features/PlanPreview/SSE/PlanSSEClient.swift (existing pattern)
// The coach SSE client is identical in structure; only the endpoint URL and
// payload type differ (ChatPayload vs UserProfile).
var request = URLRequest(url: coachChatURL)
request.httpMethod = "POST"
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.httpBody = try JSONEncoder().encode(chatPayload)

let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
```

### Pattern 4: Edge Function Response Envelope
**What:** The Edge Function streams natural language tokens, then before `[DONE]` sends a final JSON event that includes an `action` field. The iOS client buffers the stream, and after `[DONE]`, parses the envelope.

**Design approach (Claude's discretion area):**

Option A — Structured JSON throughout (like generate-plan): The entire response is a JSON schema with `action`, `text`, and optional `plan_delta`. Clean for parsing but prevents streaming raw prose tokens to the client.

Option B — Prose stream + metadata event: Stream prose tokens freely (GPT-4o mini native text); append a special `data: [ACTION]{"action":"chat"}` event at the end that the client detects. Client displays streamed text and ignores the metadata event in the bubble.

**Recommendation:** Option B. It lets GPT-4o mini generate natural prose without JSON wrapping overhead, and the action metadata arrives as a separate parseable event. The client keys on a distinct `[ACTION]` prefix rather than trying to parse partial SSE JSON.

```typescript
// Edge Function: send metadata event before [DONE]
// After forwarding the OpenAI stream, inject one more SSE event:
const actionPayload = JSON.stringify({ action: "chat" }); // or "modify_plan" + plan_delta
controller.enqueue(encoder.encode(`data: [ACTION]${actionPayload}\n\n`));
controller.enqueue(encoder.encode("data: [DONE]\n\n"));
```

```swift
// iOS: detect action event in SSE parser
if data.hasPrefix("[ACTION]") {
    let jsonString = String(data.dropFirst(8))
    // parse CoachResponseEnvelope from jsonString
    continuation.yield(.action(envelope))
} else if data == "[DONE]" {
    continuation.finish()
}
```

### Pattern 5: CDChatMessage CoreData Entity (Claude's discretion)

**Recommended schema:**
```xml
<entity name="CDChatMessage" representedClassName="CDChatMessage"
        syncable="YES" codeGenerationType="class">
    <attribute name="id" attributeType="UUID" usesScalarValueType="NO"/>
    <attribute name="userId" attributeType="String"/>
    <attribute name="role" attributeType="String"/>
    <!-- "user" or "coach" — drives bubble alignment -->
    <attribute name="content" attributeType="String"/>
    <attribute name="createdAt" attributeType="Date" usesScalarValueType="NO"/>
    <attribute name="syncedToSupabase" attributeType="Boolean"
               defaultValueString="NO" usesScalarValueType="YES"/>
    <attribute name="planModificationJSON" optional="YES" attributeType="String"/>
    <!-- Non-nil when role=="coach" and this message had a plan modification card -->
    <attribute name="planModificationState" optional="YES" attributeType="String"/>
    <!-- "pending" | "confirmed" | "dismissed" — drives card UI state -->
</entity>
```

**Rationale:** Storing plan modification state on the message record means the diff card renders correctly from history (shows "Plan updated ✓" for confirmed modifications).

### Pattern 6: coach_messages Supabase Table Schema (Claude's discretion)

**Recommended schema:**
```sql
create table coach_messages (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  role         text not null check (role in ('user', 'coach')),
  content      text not null,
  created_at   timestamptz not null default now(),
  plan_modification_json  text,     -- serialized diff, null for plain messages
  plan_modification_state text      -- 'pending' | 'confirmed' | 'dismissed'
);

-- Row Level Security: users can only read/write their own messages
alter table coach_messages enable row level security;
create policy "user_owns_messages" on coach_messages
  for all using (auth.uid() = user_id);

-- Index for sorted history fetch
create index on coach_messages (user_id, created_at desc);
```

### Pattern 7: System Prompt Assembly (D-28 to D-30)

The Edge Function receives a `ChatPayload` from iOS and builds the system prompt server-side. This keeps the prompt template out of the app binary and allows iteration without app updates.

**ChatPayload structure:**
```typescript
interface ChatPayload {
  message: string;          // User's current message
  message_history: Array<{role: "user"|"assistant", content: string}>;
  // Last N messages for conversation context (iOS manages this window)
  profile: {
    goal: string;
    fitness_level: string;
    equipment: string[];
    injuries?: string;
    name?: string;           // D-26: coach uses name occasionally
  };
  current_plan: object;     // Full WorkoutPlan JSON
  session_summaries: Array<{
    date: string;
    workout_name: string;
    exercises_completed: number;
    sets_logged: number;
  }>;                        // D-29: last 3 sessions only
  message_count: number;    // Total message count for summarization trigger (D-22)
  action?: "execute_modify"; // Set by iOS on [Confirm] tap (D-09)
  pending_modification?: object; // The proposed change to execute
}
```

### Anti-Patterns to Avoid

- **Parsing SSE JSON incrementally during streaming:** Partial JSON from OpenAI deltas is invalid until `[DONE]`. Only the `.completed` / `.action` events are parseable. The existing `PlanSSEClient` comment calls this out as PITFALL 3.
- **Calling OpenAI directly from the iOS client:** Violates the project's core security contract (CLAUDE.md). All AI calls through the Edge Function proxy.
- **Growing the message_history array unboundedly in the request payload:** Cap the history passed to the Edge Function at the last N messages (e.g., 20). D-22 handles server-side summarization; D-30 bounds the context injected.
- **Blocking the main thread for CoreData writes during streaming:** Use `context.perform {}` or a background context for writes that happen during active streaming. The `viewContext` is fine for reads and state binding but not for high-frequency writes.
- **Forgetting the `apikey` header on manual URLRequests:** The Supabase Edge Function router requires BOTH `Authorization: Bearer <token>` AND `apikey: <anon-key>`. Missing `apikey` causes 401. Already documented in `PlanSSEClient.swift` comments.
- **Using `supabase.functions.invokeWithStreamedResponse`:** Drops the JWT auth header (SDK bug #634). Must use manual `URLRequest` for all streaming calls. Already established pattern.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Chat auto-scroll to bottom | Custom scroll position tracking | `.defaultScrollAnchor(.bottom)` + `ScrollViewReader.scrollTo` | Apple-native; handles content size changes correctly [VERIFIED: developer.apple.com] |
| Auto-expanding text input | Custom `TextEditor` with height binding | `TextField(axis: .vertical).lineLimit(1...4)` | Native iOS 16+ behavior; no geometry reader, no UIKit wrapper needed [VERIFIED: developer.apple.com] |
| Date section headers | Custom date formatting | `RelativeDateTimeFormatter` + grouping by calendar day | Standard API; handles "Today", "Yesterday", older dates automatically |
| Network connectivity | Custom ping / reachability | `NWPathMonitor` (already in `SessionSyncService.swift`) | Exact pattern already proven in the project. Copy, don't reimplement. |
| OpenAI streaming proxy | New HTTP client | Extend `generate-plan` Edge Function SSE pattern | Pattern already works and is tested with real Supabase deployment |
| JWT auth on Edge Function requests | Custom auth middleware | Bearer header on manual URLRequest (existing PlanSSEClient pattern) | Already solves SDK bug #634; don't re-solve |
| Plan Structured Outputs schema | Custom JSON parser for plan modifications | Reuse `planSchema` from `generate-plan/index.ts` | The schema is already correct and tested; plan modification returns the same shape |

**Key insight:** Every infrastructure problem in this phase has already been solved somewhere in the codebase. Research the existing code first, extend second.

---

## Common Pitfalls

### Pitfall 1: Forgetting the `apikey` Header on Manual URLRequests
**What goes wrong:** 401 Unauthorized from the Edge Function even with a valid Bearer token.
**Why it happens:** Supabase Edge Function routing requires the `apikey` header in addition to `Authorization`. The SDK normally sets this automatically, but manual URLRequests bypass the SDK.
**How to avoid:** Always set both headers (see `PlanSSEClient.swift` lines 84-87):
```swift
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
```
**Warning signs:** HTTP 401 from the Edge Function with a valid user session.

### Pitfall 2: Streaming Cursor Keeps Pulsing After Response Completes
**What goes wrong:** The pulsing cursor (D-04) remains visible after streaming ends because `isStreaming` was not cleared.
**Why it happens:** The `AsyncThrowingStream` continuation completes silently; if the ViewModel doesn't observe completion, it never clears the flag.
**How to avoid:** Use a `defer { isStreaming = false }` guard at the start of the streaming task, or explicit `.completed` event handling that sets the flag before committing the message.

### Pitfall 3: Plan Modification Card State Lost on App Restart
**What goes wrong:** After an app restart, old plan modification cards show as "pending" even though the user never acted on them.
**Why it happens:** `planModificationState` was not persisted to CoreData before the app was backgrounded.
**How to avoid:** Write `planModificationState = "pending"` to CoreData at the same time the coach message is written (immediately after streaming completes), not when the card is rendered.

### Pitfall 4: Concurrent Supabase Syncs on Rapid Message Exchange
**What goes wrong:** User sends multiple messages quickly; sync calls overlap and cause duplicate or out-of-order records in `coach_messages`.
**Why it happens:** Each `sendMessage` call triggers a sync after completion; if the user sends before the first sync finishes, two sync tasks run concurrently.
**How to avoid:** Use a `isSyncing: Bool` guard (same pattern as `SessionSyncService.isSyncing`). Queue syncs sequentially, or use an actor-isolated sync task.

### Pitfall 5: Context Window Overflow Without Summarization
**What goes wrong:** After many messages, the payload sent to the Edge Function exceeds GPT-4o mini's context window, causing truncated responses or API errors.
**Why it happens:** The full `message_history` array is included in every request payload without pruning.
**How to avoid:** Cap `message_history` in the iOS payload at the last 20 messages. For the server-side summarization (D-22), trigger when `message_count` exceeds the threshold (suggested 50); the Edge Function replaces older messages with a compressed summary injected into the system prompt.

### Pitfall 6: Plan Modification Targeting Wrong Plan Version
**What goes wrong:** The user has a new plan generated between when they asked for a modification and when they tap [Confirm]; the modification is applied to the old plan.
**Why it happens:** `pending_modification` in the payload references the plan that was current when the coach proposed the change.
**How to avoid:** When the [Confirm] payload is assembled, always read the current `CDWorkoutPlan.rawJSON` from CoreData (not a cached copy), and include the plan's `supabaseId` in the modification request so the Edge Function can validate it hasn't changed.

### Pitfall 7: LazyVStack Reuses Chat Bubble Views and Breaks Streaming
**What goes wrong:** Chat bubbles flicker or display wrong content during streaming because `LazyVStack` recycles cells.
**Why it happens:** `LazyVStack` creates/destroys rows as they scroll in/out. The streaming pending message is a volatile state that doesn't fit the standard `id`-based ForEach contract.
**How to avoid:** The streaming-in-progress message should be a separate view appended OUTSIDE the `ForEach(viewModel.messages)` loop -- it's a transient, non-persisted bubble that becomes a real message only after streaming completes.

---

## Code Examples

### Pulsing Cursor View (D-04)
```swift
// No external source — standard SwiftUI animation pattern
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

### Chat Date Section Headers (D-18)
```swift
// Groups messages by calendar day, renders "Today", "Yesterday", or formatted date
// Source: standard Swift Calendar API — no external library
func sectionTitle(for date: Date) -> String {
    if Calendar.current.isDateInToday(date) { return "Today" }
    if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
    return date.formatted(date: .abbreviated, time: .omitted)
}
```

### Offline Banner — Reuse NWPathMonitor (D-32)
```swift
// Source: WorkoutApp/Core/Sync/SessionSyncService.swift — established pattern
// CoachViewModel owns an NWPathMonitor and publishes isOnline: Bool
// CoachView conditionally shows the banner above the input bar:
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

### Plan Modification Structured Outputs (D-09, D-14)
```typescript
// Source: supabase/functions/generate-plan/index.ts — reuse planSchema
// On action == "execute_modify", the Edge Function calls GPT-4o with the same
// planSchema used in generate-plan. Only the days array is modified; other days
// are returned unchanged. The iOS client merges the returned days into CDWorkoutPlan.
const modifyResponse = await fetch("https://api.openai.com/v1/chat/completions", {
  method: "POST",
  headers: { "Authorization": `Bearer ${openAIKey}`, "Content-Type": "application/json" },
  body: JSON.stringify({
    model: "gpt-4o-2024-08-06",
    stream: false,           // modification: non-streaming, wait for full plan
    response_format: {
      type: "json_schema",
      json_schema: { name: "workout_plan", strict: true, schema: planSchema },
    },
    messages: [
      { role: "system", content: modificationSystemPrompt },
      { role: "user", content: modificationUserMessage },
    ],
  }),
});
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `NavigationView` | `NavigationStack` | iOS 16 | Project already uses NavigationStack; no change needed |
| `ObservableObject` + `@Published` | `@Observable` macro | Swift 5.9 / iOS 17 | Project already uses `@Observable`; CoachViewModel follows same pattern |
| `TextEditor` for expandable input | `TextField(axis: .vertical)` + `lineLimit(1...4)` | iOS 16 | Native auto-expansion without custom height tracking [VERIFIED: developer.apple.com] |
| Combine for async streams | `AsyncThrowingStream` | Swift 5.5+ | Already established in PlanSSEClient |
| Manual scroll position tracking | `.defaultScrollAnchor(.bottom)` | iOS 17 | Cleaner chat auto-scroll; project targets iOS 16+ so use `ScrollViewReader` fallback |

**iOS 16 vs iOS 17 note:** `.defaultScrollAnchor(.bottom)` requires iOS 17. The project CLAUDE.md states iOS 16+ as the minimum. Use `ScrollViewReader` + `.onChange` for guaranteed iOS 16 compatibility, with the optional `.defaultScrollAnchor(.bottom)` as a `@available(iOS 17, *)` enhancement.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The `action` discriminator approach (Option B: prose stream + metadata event) is feasible — OpenAI allows additional SSE events to be injected by the proxy before `[DONE]` | Architecture Patterns / Pattern 4 | If OpenAI's SSE passthrough is a strict pipe that can't have extra events appended, the Edge Function must buffer and re-emit the stream rather than passing it through directly. Low risk: generate-plan already does passthrough; the coach function would simply inject one additional event after the passthrough loop. |
| A2 | The plan modification result can use the existing `planSchema` from `generate-plan/index.ts` unchanged | Code Examples | If the modification only needs to return affected days (not the full plan), a partial schema would be more efficient. The current approach returns the full plan — safe but potentially over-generates. Could optimize in Phase 8. |
| A3 | `CDChatMessage` can be added to the existing `WorkoutApp.xcdatamodeld` via a lightweight migration (no data loss) | Standard Stack | CoreData lightweight migrations work for adding new entities; only fails if existing attribute types change. This is a new entity with no relationships to existing entities — lightweight migration applies. [ASSUMED — not verified with Apple docs on migration behavior] |
| A4 | iOS 16 minimum supports `TextField(axis: .vertical)` with `lineLimit(1...4)` | Standard Stack | API docs confirm iOS 16.0+ for `init(_:text:prompt:axis:)` [VERIFIED: developer.apple.com]; confirmed safe. |

---

## Open Questions (RESOLVED)

1. **Context summarization implementation detail (D-22)** (RESOLVED)
   - **Decision:** Server-side summarization in the Edge Function. When `message_count > 50` (threshold -- Claude's discretion per CONTEXT.md), the Edge Function makes a preliminary GPT-4o mini call (non-streaming, max 300 tokens) with a dedicated summarization prompt to compress older messages into a 2-3 sentence summary. The summary is injected into the system prompt as a "Conversation summary (older messages)" section. Only the last 5 raw messages are kept in the conversation context alongside the summary. The summary is ephemeral (rebuilt each request, not stored). On failure, falls back gracefully to the capped 20-message raw history.
   - **Rationale:** Server-side keeps prompt logic out of the client. Ephemeral summaries avoid stale cache issues. The extra GPT-4o mini call adds ~1-2s latency but only triggers after 50+ messages (rare in early usage).

2. **Plan modification scope detection** (RESOLVED)
   - **Decision:** System prompt instruction-based detection. The system prompt includes explicit instructions: "When the user asks to change, swap, replace, adjust, or modify any part of their workout plan, end your response with a `[MODIFICATION]{...}` JSON block on its own line." The Edge Function accumulates the full streamed response text, then checks for the `[MODIFICATION]` tag via regex after `[DONE]`. If found, the `[ACTION]` envelope event is set to `"modify_plan"` with the extracted JSON as `plan_delta`. No second API call needed for intent classification.
   - **Rationale:** Single-pass approach (option C from the original analysis) is simplest and cheapest. The model reliably follows structured output instructions when they are explicit in the system prompt. The `[MODIFICATION]` tag is streamed as text but stripped by the iOS client before display.

3. **Plan modification partial vs. full plan return** (RESOLVED)
   - **Decision:** Return the full plan using the existing `planSchema` from `generate-plan/index.ts`. The iOS client replaces `CDWorkoutPlan.rawJSON` entirely and re-parses `CDWorkoutDay`/`CDPlannedExercise` from the new JSON. No partial merge logic needed.
   - **Rationale:** Plan JSON is small (<5KB). Full plan return is simpler to implement and eliminates an entire class of merge bugs (partial updates missing exercises, day ordering issues). The cost difference is negligible (one GPT-4o call either way). Partial return optimization can be considered in Phase 8 if plan sizes grow.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Supabase CLI | Edge Function local dev + deploy | Not checked in research | — | Deploy via `supabase functions deploy coach-chat` directly |
| OpenAI API key | coach-chat Edge Function | Set in Supabase project env (generate-plan already uses it) | — | No fallback — required |
| Xcode 16+ | Swift 6, SwiftUI | [ASSUMED: development machine already running] | 16+ | — |
| Supabase project (hosted) | All backend work | Active (generate-plan deployed and working) [VERIFIED: codebase] | — | — |

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest |
| Config file | WorkoutAppTests target in Xcode project |
| Quick run command | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:WorkoutAppTests` |
| Full suite command | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CHAT-01 | CoachViewModel.sendMessage() creates pending message and starts streaming state | unit | `xcodebuild test -only-testing:WorkoutAppTests/CoachViewModelTests` | No (Wave 0) |
| CHAT-01 | CoachSSEClient parses `.token` events from SSE stream | unit | `xcodebuild test -only-testing:WorkoutAppTests/CoachSSEClientTests` | No (Wave 0) |
| CHAT-01 | Offline state disables send and shows banner | unit | `xcodebuild test -only-testing:WorkoutAppTests/CoachViewModelTests/testOfflineDisablesSend` | No (Wave 0) |
| CHAT-02 | Action envelope parsed correctly (`"modify_plan"` triggers card state) | unit | `xcodebuild test -only-testing:WorkoutAppTests/CoachViewModelTests/testModifyPlanActionTriggersCard` | No (Wave 0) |
| CHAT-02 | [Confirm] tap sets planModificationState = "confirmed" in CoreData | unit | `xcodebuild test -only-testing:WorkoutAppTests/CoachViewModelTests/testConfirmPlanModification` | No (Wave 0) |
| CHAT-02 | [Dismiss] tap sets planModificationState = "dismissed" | unit | `xcodebuild test -only-testing:WorkoutAppTests/CoachViewModelTests/testDismissPlanModification` | No (Wave 0) |
| CHAT-03 | System prompt payload includes profile + plan + last 3 session summaries | unit | `xcodebuild test -only-testing:WorkoutAppTests/CoachViewModelTests/testSystemPromptPayloadContents` | No (Wave 0) |
| CHAT-03 | Message payload caps message_history at last 20 messages | unit | `xcodebuild test -only-testing:WorkoutAppTests/CoachViewModelTests/testMessageHistoryCap` | No (Wave 0) |

### Sampling Rate
- **Per task commit:** Build check — `xcodebuild build -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16'`
- **Per wave merge:** `xcodebuild test -only-testing:WorkoutAppTests/CoachViewModelTests`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `WorkoutAppTests/CoachViewModelTests.swift` — covers CHAT-01, CHAT-02, CHAT-03
- [ ] `WorkoutAppTests/CoachSSEClientTests.swift` — covers SSE parsing, error cases
- [ ] `WorkoutApp/Features/Coach/CoachViewModel.swift` — required before tests can compile

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Bearer JWT on every Edge Function request (established pattern from generate-plan) |
| V3 Session Management | no | Handled by Supabase Auth — no changes in Phase 5 |
| V4 Access Control | yes | Row Level Security on `coach_messages` table (user can only read/write own messages) |
| V5 Input Validation | yes | Edge Function: message length limit (e.g., 2000 chars), validate payload fields, truncate before prompt injection |
| V6 Cryptography | no | No new cryptographic operations — tokens stored in Keychain (established) |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Prompt injection via user message | Tampering | Length limit on `message` field server-side (<=2000 chars); system prompt placed before user content in messages array; OpenAI safety layer as secondary defense |
| Medical advice extraction via leading questions | Elevation of Privilege | System prompt safety guardrail (SAFE-02): "Do not diagnose conditions, prescribe treatments, or provide medical advice" — same guardrail from generate-plan system prompt |
| Replay of old plan modification payloads | Tampering | Include current `plan_supabase_id` in the modification request; Edge Function validates it matches the current plan in Supabase |
| API key extraction from app binary | Information Disclosure | All OpenAI calls through Edge Function — API key is a Deno environment variable, never in the iOS binary [VERIFIED: CLAUDE.md] |
| Token abuse via rapid message sending | Denial of Service | Rate limiting per user in the Edge Function (add per-user request count check, e.g., max 60 requests/hour) |

---

## Sources

### Primary (HIGH confidence)
- `WorkoutApp/Features/PlanPreview/SSE/PlanSSEClient.swift` — SSE pattern, auth header workaround [VERIFIED: codebase]
- `supabase/functions/generate-plan/index.ts` — Edge Function SSE passthrough, OpenAI Structured Outputs [VERIFIED: codebase]
- `WorkoutApp/Core/Sync/SessionSyncService.swift` — NWPathMonitor pattern [VERIFIED: codebase]
- `WorkoutApp/Core/Data/WorkoutApp.xcdatamodeld` — Existing CoreData schema [VERIFIED: codebase]
- developer.apple.com — `TextField(axis: .vertical)`, `lineLimit(1...4)`, `defaultScrollAnchor(.bottom)`, `ScrollViewReader` [VERIFIED: Context7 / official Apple docs]
- supabase.com/docs — Edge Function SSE streaming pattern [VERIFIED: Context7]
- `WorkoutApp/Core/AppState.swift` — User profile + subscription state available [VERIFIED: codebase]

### Secondary (MEDIUM confidence)
- CLAUDE.md technology stack table — two-model strategy (GPT-4o mini for chat, GPT-4o for plan modification), RevenueCat, Supabase as canonical choices
- npm registry — openai@6.34.0, supabase@2.95.0 [VERIFIED: npm view]

### Tertiary (LOW confidence)
- None — all key claims verified from codebase or official docs in this session.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already in project; versions verified
- Architecture: HIGH — SSE pattern, MVVM pattern, and CoreData pattern all verified in existing codebase
- Pitfalls: HIGH — most are documented directly in existing code comments (PlanSSEClient PITFALL 1/3, SessionSyncService isSyncing guard)
- SwiftUI auto-scroll: HIGH — verified via Context7 / Apple official docs
- Edge Function response envelope design: MEDIUM — Option B (prose + metadata event) is a design recommendation; no prior art in this codebase yet

**Research date:** 2026-04-23
**Valid until:** 2026-05-23 (stable stack — iOS/Supabase/OpenAI APIs are unlikely to break compatibility within 30 days)
