# Architecture Research

**Domain:** AI-powered iPhone workout app
**Researched:** 2026-04-16
**Confidence:** HIGH (iOS patterns), MEDIUM (AI backend integration specifics)

## Standard Architecture

### System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                          iOS App (SwiftUI)                            │
│                                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐  │
│  │  Onboarding  │  │   Session   │  │    Coach    │  │  Progress  │  │
│  │    Flow      │  │  Workout    │  │    Chat     │  │  History   │  │
│  └──────┬───────┘  └─────┬───────┘  └──────┬──────┘  └─────┬──────┘  │
│         │                │                  │               │         │
│  ┌──────┴───────────────────────────────────┴───────────────┴──────┐  │
│  │              ViewModels (@Observable)                           │  │
│  │   PlanVM  │  SessionVM  │  ChatVM  │  ProfileVM  │  ProgressVM  │  │
│  └──────────────────────────────┬──────────────────────────────────┘  │
│                                 │                                     │
│  ┌──────────────────────────────┴──────────────────────────────────┐  │
│  │                     Service Layer                               │  │
│  │  AIService  │  WorkoutService  │  VideoService  │  AuthService  │  │
│  └──────────────────────────────┬──────────────────────────────────┘  │
│                                 │                                     │
│  ┌──────────────────────────────┴──────────────────────────────────┐  │
│  │                Local Persistence (SwiftData)                    │  │
│  │   WorkoutPlan  │  Session  │  Exercise  │  UserProfile  │  Chat  │  │
│  └─────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
                                  │
              ┌───────────────────┼────────────────────┐
              ▼                   ▼                    ▼
┌─────────────────────┐  ┌─────────────────┐  ┌───────────────────┐
│   Supabase Backend  │  │  AI Gateway     │  │   Video CDN       │
│                     │  │  (Edge Fn)      │  │   (Mux/CF Stream) │
│  - Auth             │  │                 │  │                   │
│  - User profiles    │  │  - Plan gen     │  │  - HLS video      │
│  - Workout history  │  │  - Chat stream  │  │  - Signed URLs    │
│  - Sync state       │  │  - Adaptation   │  │  - Adaptive BR    │
│  - Subscriptions    │  │  → OpenAI/      │  │                   │
│    (RevenueCat)     │  │    Anthropic     │  │                   │
└─────────────────────┘  └─────────────────┘  └───────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| SwiftUI Views | Render UI, capture user input, play video | ViewModels only |
| ViewModels (@Observable) | State ownership, async coordination, business logic | Service layer, SwiftData |
| Service Layer | Abstracts external I/O (network, persistence, purchases) | Supabase, AI Gateway, Video CDN, StoreKit |
| SwiftData Models | Local persistence, offline data, session cache | Service layer |
| Supabase Auth | JWT-based auth, user sessions, Row Level Security | iOS SDK direct |
| Supabase DB | User profiles, workout history, plan metadata | Supabase Edge Functions, iOS SDK |
| AI Gateway (Edge Functions) | Proxy LLM calls, inject system context, stream responses | OpenAI/Anthropic, Supabase DB |
| Video CDN | Store and deliver HLS animatic videos with signed tokens | iOS AVPlayer via URL |
| RevenueCat | Subscription state, entitlement verification, receipt validation | StoreKit 2, Supabase (webhooks) |

---

## Recommended Project Structure

```
WorkoutApp/
├── App/
│   ├── WorkoutApp.swift         # App entry, dependency injection root
│   └── AppRouter.swift          # Navigation state machine
│
├── Features/                    # Feature modules — one folder per screen cluster
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── OnboardingViewModel.swift
│   ├── WorkoutSession/
│   │   ├── SessionView.swift
│   │   ├── SessionViewModel.swift
│   │   ├── ExercisePlayerView.swift   # AVPlayer wrapper
│   │   └── TimerView.swift
│   ├── AICoach/
│   │   ├── ChatView.swift
│   │   ├── ChatViewModel.swift
│   │   └── PlanGenerationViewModel.swift
│   ├── ExerciseLibrary/
│   │   ├── LibraryView.swift
│   │   └── LibraryViewModel.swift
│   ├── Progress/
│   │   ├── ProgressView.swift
│   │   └── ProgressViewModel.swift
│   └── Subscription/
│       ├── PaywallView.swift
│       └── SubscriptionViewModel.swift
│
├── Services/                    # I/O abstractions — testable, injectable
│   ├── AI/
│   │   ├── AIService.swift           # Protocol + impl
│   │   └── AIStreamParser.swift      # SSE/AsyncStream parser
│   ├── Supabase/
│   │   ├── SupabaseClient.swift      # Singleton client config
│   │   ├── AuthService.swift
│   │   └── WorkoutRepository.swift
│   ├── Video/
│   │   └── VideoService.swift        # Signed URL fetching, AVPlayer setup
│   └── Purchases/
│       └── PurchaseService.swift     # RevenueCat wrapper
│
├── Models/                      # SwiftData models + domain types
│   ├── Persistence/
│   │   ├── WorkoutPlan.swift         # @Model
│   │   ├── WorkoutSession.swift      # @Model
│   │   ├── Exercise.swift            # @Model
│   │   └── UserProfile.swift         # @Model
│   └── Domain/
│       ├── ChatMessage.swift
│       ├── Plan.swift
│       └── EquipmentContext.swift
│
└── Shared/                      # Utilities, design system, extensions
    ├── UI/
    │   ├── DesignTokens.swift
    │   └── Components/
    └── Extensions/
```

### Structure Rationale

- **Features/ by screen cluster:** Each feature owns its views + viewmodels. Co-location makes navigation and ownership obvious.
- **Services/ separate from Features/:** Services are I/O adapters. They can be mocked for testing and swapped without touching views.
- **Models/ split persistence vs domain:** SwiftData `@Model` classes carry persistence annotations; clean domain types are plain Swift structs passed through the app.
- **No circular dependencies:** Views → ViewModels → Services → Models. Never reverse.

---

## Architectural Patterns

### Pattern 1: MVVM with @Observable (Modern Swift, iOS 17+)

**What:** ViewModels declared with `@Observable` macro; views bind directly to properties without `@ObservedObject` boilerplate. State changes propagate precisely — only views accessing a changed property re-render.

**When to use:** All feature screens. This is the recommended default for new SwiftUI apps in 2025.

**Trade-offs:** Requires iOS 17+. Simpler than TCA. Excellent fit here since the project is iOS-only and can target iOS 17.

**Example:**
```swift
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var isStreaming = false
    var inputText = ""

    private let aiService: AIServiceProtocol

    init(aiService: AIServiceProtocol) {
        self.aiService = aiService
    }

    func sendMessage() async {
        let userMsg = ChatMessage(role: .user, content: inputText)
        messages.append(userMsg)
        inputText = ""
        isStreaming = true

        var assistantMsg = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMsg)

        for await chunk in aiService.streamMessage(history: messages) {
            assistantMsg.content += chunk
            messages[messages.count - 1] = assistantMsg
        }
        isStreaming = false
    }
}
```

### Pattern 2: AI Streaming via AsyncThrowingStream

**What:** Backend Edge Function proxies LLM call and returns SSE. iOS service layer converts SSE chunks into an `AsyncThrowingStream<String, Error>`. ViewModel consumes with `for await`.

**When to use:** All AI interactions — chat responses AND plan generation. Streaming prevents perceived latency and gives users instant feedback.

**Trade-offs:** Requires proper cancellation handling (Task cancellation propagates through the stream). SSE parsing is ~30 lines of boilerplate but well-understood.

**Example:**
```swift
// AIService.swift
func streamChatResponse(history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
        Task {
            let request = buildRequest(history: history)
            let (bytes, _) = try await URLSession.shared.bytes(for: request)
            for try await line in bytes.lines {
                guard line.hasPrefix("data: "), line != "data: [DONE]" else { continue }
                let jsonData = Data(line.dropFirst(6).utf8)
                if let chunk = try? JSONDecoder().decode(StreamChunk.self, from: jsonData) {
                    continuation.yield(chunk.delta)
                }
            }
            continuation.finish()
        }
    }
}
```

### Pattern 3: Offline-First with SwiftData + Background Sync

**What:** All workout data written to SwiftData immediately. Network sync happens in background after local write succeeds. UI always reads from local store — network is never in the critical path for active workout.

**When to use:** Workout sessions (non-negotiable offline), exercise library (cache on first load), workout history. NOT for subscription state (always requires network verification).

**Trade-offs:** Conflict resolution needed when offline edits and server disagree. For workout data this is rare and last-write-wins is acceptable. More complex for plan modifications during offline periods.

**Example:**
```swift
// WorkoutService.swift
func completeSet(_ set: ExerciseSet, in session: WorkoutSession) async {
    // 1. Write locally — instant, never fails
    session.completedSets.append(set)
    try? modelContext.save()

    // 2. Sync in background — failure is non-blocking
    Task.detached(priority: .background) {
        try? await supabase.from("completed_sets").insert(set.toRemote())
    }
}
```

### Pattern 4: AI Context Management (Sliding Window + Profile Injection)

**What:** Conversation history is NOT sent raw to the LLM. The Edge Function assembles context from: (1) a fixed system prompt with user profile, equipment, and current plan, (2) a sliding window of recent messages (last N turns to stay within context limits), (3) session state (current workout if active).

**When to use:** Every AI API call. Without this, costs balloon and context drifts.

**Trade-offs:** Requires Edge Function to own context assembly — not the iOS client. This keeps the system prompt off the device and enables prompt tuning without app updates.

**Example (Edge Function pseudocode):**
```typescript
async function buildContext(userId: string, history: Message[]): Promise<Message[]> {
    const profile = await db.getUserProfile(userId)
    const activePlan = await db.getActivePlan(userId)

    const systemPrompt = buildSystemPrompt(profile, activePlan) // injected server-side

    const recentHistory = history.slice(-20) // sliding window: last 20 turns

    return [
        { role: "system", content: systemPrompt },
        ...recentHistory
    ]
}
```

---

## Data Flow

### Flow 1: AI Plan Generation

```
User completes onboarding
    ↓
OnboardingViewModel sends profile to AIService
    ↓
AIService → POST /functions/v1/generate-plan (Supabase Edge Fn)
    ↓
Edge Fn queries user profile from Supabase DB
    ↓
Edge Fn builds prompt + calls OpenAI (streaming)
    ↓
SSE chunks stream back to iOS → AsyncThrowingStream
    ↓
PlanGenerationViewModel renders plan progressively
    ↓
On stream complete: plan saved to SwiftData (local) + Supabase DB (remote)
```

### Flow 2: Live Workout Session

```
User starts workout (taps session)
    ↓
SessionViewModel loads WorkoutPlan from SwiftData (local, instant)
    ↓
Video URLs fetched from VideoService → signed CDN URLs
    ↓
AVPlayer preloads first exercise video
    ↓
User progresses through sets → all writes go to SwiftData immediately
    ↓
Timer/rep events fire → SessionViewModel updates local state
    ↓
Session completes → WorkoutSession saved to SwiftData
    ↓
Background task syncs completed session to Supabase
    ↓
Background task triggers AI adaptation call (next session difficulty)
```

### Flow 3: AI Chat (Coach)

```
User sends message
    ↓
ChatViewModel appends message, calls AIService.streamChatResponse()
    ↓
AIService → POST /functions/v1/chat (Supabase Edge Fn with streaming=true)
    ↓
Edge Fn: loads user profile + recent session data + sliding window history
    ↓
Edge Fn calls OpenAI with assembled context → streams SSE back
    ↓
iOS reads AsyncThrowingStream, appends chunks to last message in real-time
    ↓
On stream complete: full conversation saved to SwiftData
    ↓
If plan modification requested: follow-up call to plan-update Edge Fn
```

### Flow 4: Subscription Check

```
App launch
    ↓
PurchaseService queries RevenueCat for CustomerInfo
    ↓
RevenueCat verifies receipt with Apple + returns entitlement status
    ↓
App-level entitlement state set (@Observable, injected via Environment)
    ↓
Feature gates check entitlement before presenting paywalled screens
    ↓
RevenueCat webhook → Supabase → update user subscription record
```

### State Management

```
SwiftData (source of truth for local data)
    ↓ (read via @Query or modelContext.fetch)
ViewModels (@Observable — own screen-level state)
    ↓ (bindings)
SwiftUI Views (render only)

Network events → Services → ViewModels (never directly to Views)
```

---

## iOS-Specific Architecture Decisions

### Navigation: NavigationStack + Coordinator Pattern

Use `NavigationStack` with a centralized `AppRouter` @Observable class holding navigation path. Feature screens push/pop via the router, not direct NavigationLink bindings. This enables deep linking, in-session navigation, and testable navigation flows.

### Dependency Injection: Environment + Constructor Injection

Inject services at app root via SwiftUI `Environment`. Feature ViewModels receive services via initializer. Avoids global singletons and enables test mocking.

```swift
// App root
.environment(AIService(client: supabase))
.environment(PurchaseService())

// ViewModel constructor
init(aiService: AIService = .shared) { ... } // fallback for previews
```

### Concurrency: Actors for Thread Safety

Background sync tasks run as Swift actors to prevent data races. Main actor isolation for all ViewModel @Observable properties (automatic with @MainActor annotation).

---

## Backend Architecture: Supabase (Recommended)

**Why Supabase over Firebase:**
- PostgreSQL gives relational workout data modeling (plans → sessions → sets → exercises) with proper foreign keys
- pgvector extension enables future semantic search over exercise library or conversation history
- Edge Functions support SSE streaming to iOS clients (confirmed working)
- Row Level Security (RLS) provides data isolation per user without application-layer guards
- Open source — no vendor lock-in, can self-host if needed
- Pricing more favorable than Firebase for high AI query volumes

**Supabase Schema (logical):**

```
users (Supabase Auth)
  └── user_profiles (fitness level, goals, equipment)
  └── workout_plans (AI-generated, versioned)
        └── workout_sessions (completed instances)
              └── completed_sets (exercise, reps, weight)
  └── chat_messages (conversation history)
  └── subscription_status (synced from RevenueCat webhook)

exercises (global table, not per-user)
  └── exercise_videos (CDN URLs, signed token metadata)
```

**Edge Functions (AI Gateway):**

| Function | Trigger | Responsibility |
|----------|---------|---------------|
| `generate-plan` | Onboarding complete | Build plan prompt, call LLM, stream response, save plan |
| `chat` | User sends message | Assemble context window, proxy LLM stream |
| `adapt-session` | Session complete | Analyze performance, adjust next session difficulty |
| `update-plan` | Coach requests modification | Parse intent, update plan record |

---

## Video Architecture

**Delivery: Mux or Cloudflare Stream**

Both deliver HLS via global CDN, adaptive bitrate, and work natively with iOS AVPlayer. Recommendation: **Mux** for developer experience and analytics; **Cloudflare Stream** if already on Cloudflare infrastructure (simpler billing).

**Animatic videos are short (10-30 seconds), loop indefinitely during exercise sets.** Architecture implications:
- Preload the next exercise video while the current one is playing
- Videos should be pre-transcoded to HLS at source
- Signed URLs issued by Supabase Edge Function (not embedded in app) to prevent piracy of paid content
- Videos cached locally after first play — `AVURLAsset` with `NSCachesDirectory` backing

**Video security flow:**
```
SessionViewModel requests video for exercise
    ↓
VideoService calls /functions/v1/get-video-url (checks subscription entitlement)
    ↓
Edge Fn generates signed URL (5-minute expiry) from CDN
    ↓
iOS loads AVPlayer with signed HLS URL
    ↓
Subsequent plays within session: cached locally, no re-signing needed
```

---

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 0-1K users | Supabase free tier, OpenAI API direct via Edge Functions, Mux pay-as-you-go. No changes needed. |
| 1K-10K users | Upgrade Supabase plan, add response caching for common plan templates in Edge Functions, monitor LLM cost per user. |
| 10K-100K users | Evaluate LLM cost vs revenue. Consider prompt caching (Anthropic Claude has native prompt caching for system prompts — saves 90% on repeated context). Add Redis/Upstash caching for exercise library queries. |
| 100K+ users | Consider dedicated LLM inference (Groq, Bedrock, self-hosted). Separate video serving costs become significant — renegotiate CDN pricing. Supabase read replicas for workout history queries. |

### Scaling Priorities

1. **First bottleneck: LLM cost.** At scale, AI inference cost is the primary expense. Implement Anthropic's prompt caching early — system prompts are repeated on every request and caching reduces costs by up to 90% on cached tokens.
2. **Second bottleneck: Supabase connections.** Connection pooling via PgBouncer (built into Supabase) handles this; monitor pool exhaustion at 10K+ concurrent sessions.

---

## Suggested Build Order

Dependencies drive this ordering — each phase unlocks the next.

```
Phase 1: Auth + User Profile + Supabase Setup
    ↓ (auth required for everything)
Phase 2: Exercise Library + Video Delivery (CDN + AVPlayer)
    ↓ (video delivery required for session experience)
Phase 3: AI Plan Generation + Onboarding Flow
    ↓ (plan required to show a workout)
Phase 4: In-Session Workout Experience (offline-first, SwiftData)
    ↓ (session tracking required to measure progress)
Phase 5: AI Coach Chat Interface
    ↓ (chat builds on plan + session context already established)
Phase 6: Progress Tracking + Session History
    ↓ (data exists from Phase 4, now needs UI)
Phase 7: Subscriptions + Paywall (RevenueCat + StoreKit 2)
    ↓ (gates on complete product, not introduced mid-build)
Phase 8: Adaptive AI (real-time difficulty adjustment)
    (last — requires session data history to be meaningful)
```

**Rationale:**
- Subscriptions go last — build the product worth paying for first
- AI chat (Phase 5) comes after the plan/session foundation because the coach needs that context
- Offline session capability (Phase 4) must be built correctly from the start — retrofitting offline is a rewrite
- Exercise library (Phase 2) before AI planning (Phase 3) because plan generation references exercises

---

## Anti-Patterns

### Anti-Pattern 1: Putting AI Context Assembly in the iOS App

**What people do:** Send full conversation history from iOS client directly to OpenAI. Embed the system prompt in the app binary.

**Why it's wrong:** System prompt is visible via binary inspection. Client sends redundant context tokens on every call. Prompt tuning requires App Store update. No server-side cost controls.

**Do this instead:** iOS sends only user message + session ID to your Edge Function. Edge Function assembles full context server-side from DB state.

### Anti-Pattern 2: Network-Dependent Workout Sessions

**What people do:** Write set completions to the remote DB synchronously; show loading states during a workout.

**Why it's wrong:** Any network hiccup (gym WiFi, cellular dead zones) interrupts the workout experience — the app's core value prop.

**Do this instead:** Always write to SwiftData first, sync in background fire-and-forget. The workout session is fully functional with zero network.

### Anti-Pattern 3: Storing Video Files in Supabase Storage

**What people do:** Upload animatic videos to Supabase Storage bucket, serve directly from there.

**Why it's wrong:** Supabase Storage egress costs are high for video. No adaptive bitrate. No CDN edge caching globally. Buffering on mobile.

**Do this instead:** Use a purpose-built video platform (Mux, Cloudflare Stream). Store only the video asset ID in Supabase; generate signed playback URLs on demand.

### Anti-Pattern 4: Single Massive ViewModel for the Workout Session

**What people do:** Build one `SessionViewModel` that handles video, timers, rep counting, AI coaching hints, and data sync.

**Why it's wrong:** Becomes impossible to test, extend, or debug. Session logic is among the most complex in this app.

**Do this instead:** Compose smaller domain objects — `TimerController` (actor), `ExerciseProgressTracker` (struct), `VideoCoordinator` (class) — and let `SessionViewModel` orchestrate them.

### Anti-Pattern 5: RevenueCat as the Only Subscription Truth Source

**What people do:** Check subscription entitlement only via RevenueCat on the client.

**Why it's wrong:** Client-side entitlement can be bypassed. AI features in particular need server-side verification because they cost money to run.

**Do this instead:** RevenueCat webhook syncs subscription status to Supabase. Edge Functions check `subscription_status` table before allowing AI calls. Double-gated: client UI gate + server enforcement.

---

## Integration Points

### External Services

| Service | Integration Pattern | iOS SDK? | Notes |
|---------|---------------------|----------|-------|
| Supabase Auth | `supabase-swift` SDK, JWT stored in Keychain | Yes | Use `supabase-swift` v2 |
| Supabase DB | `supabase-swift` realtime + REST | Yes | RLS enforces per-user isolation |
| Supabase Edge Functions | URLSession + SSE for streaming | Manual | No native streaming SDK — build SSE parser |
| OpenAI / Anthropic | Called server-side only via Edge Functions | No | API key never on device |
| Mux (or Cloudflare Stream) | AVPlayer with HLS M3U8 URL | Via AVFoundation | Signed URL issued per session |
| RevenueCat | `purchases-ios` SDK + StoreKit 2 | Yes | SDK 5.x uses StoreKit 2 by default |
| Apple StoreKit 2 | Via RevenueCat SDK | Native | Direct StoreKit 2 for < 100K subscribers is viable if avoiding RevenueCat fee |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| View ↔ ViewModel | `@Observable` property access, `@Bindable` two-way | No direct service calls from views |
| ViewModel ↔ Services | Protocol-typed async methods | Protocol enables test mocking |
| Services ↔ SwiftData | `ModelContext` passed at init or via `@Environment` | One ModelContext per feature scope |
| iOS App ↔ Edge Functions | HTTPS REST + SSE streaming | Authenticated with Supabase JWT |
| Edge Functions ↔ LLM | HTTPS (server-to-server) | Key management via Supabase secrets vault |
| RevenueCat ↔ Supabase | Webhook (RevenueCat → Supabase Edge Fn) | Keeps subscription status current server-side |

---

## Sources

- [iOS Architecture Playbook 2025 — SwiftUI, Concurrency & Modular Design](https://medium.com/@mrhotfix/the-architecture-playbook-for-ios-2025-swiftui-concurrency-modular-design-a35b98cbf688)
- [Modern iOS App Architecture in 2026: MVVM vs Clean vs TCA — 7Span](https://7span.com/blog/mvvm-vs-clean-architecture-vs-tca)
- [Offline-First SwiftUI with SwiftData](https://medium.com/@ashitranpura27/offline-first-swiftui-with-swiftdata-clean-fast-and-sync-ready-9a4faefdeedb)
- [Build Offline-First Apps with SwiftData and Background Tasks](https://commitstudiogs.medium.com/build-offline-first-apps-with-swiftdata-and-background-tasks-a29434b6f80c)
- [Building AI-Powered Apps with Supabase in 2025](https://scaleupally.io/blog/building-ai-app-with-supabase/)
- [Supabase vs Firebase for AI Apps](https://templateai.co/blog/supabase-vs-firebase-ai-apps)
- [Supabase Edge Functions — AI Models](https://supabase.com/docs/guides/functions/ai-models)
- [Supabase Edge Functions — OpenAI Streaming](https://supabase.com/docs/guides/ai/examples/openai)
- [Build an AI Assistant for iOS using Swift — GetStream](https://getstream.io/blog/ios-assistant/)
- [OpenAI Responses Stream API in Swift](https://jamesrochabrun.medium.com/stream-real-time-ai-responses-in-swift-with-openais-response-api-ad599e532f95)
- [StoreKit 2 vs RevenueCat — The Swift Kit](https://theswiftk.it.com/blog/storekit-2-vs-revenuecat-ios-subscriptions)
- [RevenueCat SDK 5.0 — StoreKit 2 Update](https://www.revenuecat.com/blog/engineering/revenuecat-sdk-5-0-the-storekit-2-update/)
- [Mux vs Cloudflare Stream](https://www.mux.com/compare/cloudflare-stream)
- [AVPlayer Official Documentation](https://developer.apple.com/documentation/avfoundation/avplayer/)
- [How to Build a Personalized AI Fitness Coach — GeekyAnts](https://geekyants.com/blog/how-to-build-a-personalized-ai-fitness-coach-for-the-us-market---with-live-demo)

---
*Architecture research for: AI-powered iPhone workout app*
*Researched: 2026-04-16*
