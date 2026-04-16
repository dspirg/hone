# Stack Research

**Domain:** AI-powered iPhone fitness app with subscription billing
**Researched:** 2026-04-16
**Confidence:** HIGH (core stack) / MEDIUM (AI cost projections)

---

## Recommended Stack

### iOS Client

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| SwiftUI | iOS 17+ target | Primary UI framework | 70% of new apps in 2025, 40% less code than UIKit, native declarative bindings — new apps should default to SwiftUI; UIKit is for legacy or ultra-custom interactions only |
| Swift 6 | 6.x | Language | Strict concurrency by default, compile-time data race detection, async/await throughout; shipping in 2024/2025 with WWDC 2025 refinements in 6.2 |
| Swift Concurrency (async/await + Actors) | Swift 6 | Async work, networking, AI streaming | Native structured concurrency replaces Combine for most new code; TaskGroup for parallel work, Actors for mutable shared state, `Task.checkCancellation()` in long-running tasks |
| MVVM (vanilla, no framework) | — | App architecture | SwiftUI's `@Observable` / `@State` / `@Environment` make vanilla MVVM the right default; TCA is powerful but adds significant boilerplate and learning curve that slows a solo/small team |
| CoreData | iOS 16+ | Local workout history & offline cache | SwiftData is cleaner but had severe performance and memory issues on iOS 17; iOS 18 improved it but memory usage is still ~2x CoreData; for workout history (potentially thousands of entries) CoreData is the safer bet until SwiftData matures further |
| AVFoundation + AVKit | iOS 16+ | Exercise video playback | Apple-native HLS streaming; `AVPlayerViewController` for full-featured playback with transport controls; `VideoPlayer` (SwiftUI wrapper) for simpler embedded loops; both support adaptive bitrate HLS automatically |
| KeychainAccess (Swift Package) | 4.x | Secure token storage | Keychain is mandatory for auth tokens and sensitive data; raw Keychain APIs are painful; KeychainAccess is the standard thin wrapper (SPM-compatible, no Obj-C dependencies) |
| RevenueCat SDK | 5.x | Subscription billing | SDK 5.0 uses StoreKit 2 under the hood on iOS 16+; free tier up to $2,500 MRR; saves ~2 weeks of StoreKit plumbing, handles receipt validation server-side, provides analytics and A/B testing for paywalls out of the box; use raw StoreKit 2 only when you pass $100K MRR and want to cut costs |

### AI Layer

| Technology | Version/Model | Purpose | Why Recommended |
|------------|--------------|---------|-----------------|
| OpenAI API | GPT-4o (plans) + GPT-4o mini (chat) | Workout plan generation + conversational coach | Two-model strategy: GPT-4o for structured plan generation (once per session/week) where quality matters; GPT-4o mini for conversational chat (every message) at $0.15/$0.60 per million tokens vs $2.50/$10 for GPT-4o — 16x cheaper for high-frequency chat |
| OpenAI Structured Outputs | response_format with JSON Schema | Typed workout plan responses | Guarantees model always returns valid JSON matching your schema; critical for plan generation where you need predictable `exercises`, `sets`, `reps`, `rest` fields; supported on gpt-4o-2024-08-06 and later |
| OpenAI Streaming | SSE / Server-Sent Events | Coach chat responses | Stream tokens as they arrive for responsive chat UX; URLSession supports SSE natively in Swift; users perceive much faster response times |
| System prompt architecture | — | AI personalization | Store user profile (fitness level, goals, equipment, history summary) in a persistent system prompt injected on every request; never rely on conversation history alone for state |

### Backend

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Supabase | Latest (Swift SDK 2.x) | Database, auth, realtime | PostgreSQL-backed BaaS; relational data model is the right fit for workout plans, exercise libraries, session logs, and user profiles — Firestore's document model is a poor fit for relational fitness data; Swift SDK has first-class SPM support; Row Level Security enforces per-user data isolation at the DB layer |
| Supabase Auth | — | User authentication | Apple Sign-In + Email/Password; Apple Sign-In is required by App Store guidelines when you offer social auth; Supabase Auth handles JWT issuance, refresh, deep link callbacks |
| Supabase Edge Functions (Deno) | — | AI request proxy | Never call OpenAI directly from the iOS client — API keys would be extractable from the binary; all LLM calls go through an Edge Function that injects the API key server-side and applies rate limiting per user |
| Supabase Storage | — | User avatars / generated plan assets | Lightweight object storage for small user-generated content; not used for exercise videos (Mux handles that) |

### Video Delivery

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Mux | Video API | Exercise video hosting + HLS delivery | Purpose-built for fitness/SaaS video; developer-first API; serves HLS `.m3u8` URLs consumed by AVPlayer; adaptive bitrate across network conditions; built-in QoE analytics; 100K free delivery minutes/month; ~$52/month for a 5K-minute library with 50K deliveries — better pricing and developer experience than Cloudflare Stream at this scale |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Supabase Swift | 2.x | Supabase SDK (auth, database, storage) | Always — install via SPM |
| KeychainAccess | 4.x | Keychain wrapper | Always — auth token persistence |
| RevenueCat `purchases-ios` | 5.x | Subscription management | Always — paywall, entitlements, analytics |
| Lottie for iOS | 4.x | Animatic exercise video support (if using vector animations instead of MP4) | If exercise animations are delivered as Lottie JSON files instead of video; significantly smaller file sizes; works offline without CDN; decision depends on animation source/format |
| swift-openai or custom URLSession | — | OpenAI API client | Build thin URLSession wrapper over OpenAI's REST API; avoid third-party OpenAI Swift clients (they lag behind API updates); the API is simple enough that a custom client is 100–200 lines |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16+ | IDE, build, simulator | Required for Swift 6 and iOS 17 SDK |
| Swift Package Manager | Dependency management | No CocoaPods or Carthage for new projects; SPM is the standard since Xcode 12 |
| TestFlight | Beta distribution | Standard Apple beta channel; required for subscription testing with sandbox accounts |
| Supabase CLI | Local dev, migrations, Edge Function deploy | Run Supabase locally with Docker for development; `supabase db diff` for migrations |
| RevenueCat Dashboard | Subscription analytics, paywall config | Configure products, entitlements, offerings without app updates |
| Mux Dashboard | Video upload, analytics | Monitor video performance per exercise |

---

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| Supabase | Firebase Firestore | If you need real-time document sync (e.g., live multiplayer) or your team has deep Firebase experience; Firestore's document model is awkward for relational workout data |
| Supabase | AWS Amplify / custom backend | At serious scale (500K+ users) where you need full infrastructure control; Supabase's generous free tier and managed Postgres are a better early-stage choice |
| RevenueCat | Raw StoreKit 2 | When MRR exceeds $100K and RevenueCat's percentage fee exceeds the engineering cost of self-managing receipt validation; migration is straightforward since RevenueCat wraps StoreKit 2 |
| OpenAI GPT-4o / mini | Anthropic Claude 3.5 Sonnet / Haiku | Claude Haiku is comparably priced and arguably better at structured outputs; either provider works; OpenAI is recommended here because its Structured Outputs feature has better documentation for JSON schema enforcement and its ecosystem tooling is more mature for fitness plan schemas |
| Mux | Cloudflare Stream | If already running on Cloudflare Workers/Pages and want unified billing; Cloudflare Stream is simpler but lacks Mux's analytics and developer DX |
| Mux | Bundled local assets | For a small (<50 exercises) initial library where offline-first matters more than updateability; bundle MP4/Lottie in the app bundle to avoid CDN dependency, then migrate to Mux as the library grows |
| MVVM (vanilla) | The Composable Architecture (TCA) | If the team is 3+ engineers with TCA experience, building highly testable complex state machines; TCA is overkill for an MVP and slows iteration speed |
| CoreData | SwiftData | Once SwiftData's migration story matures (likely iOS 19 target); it's architecturally cleaner but performance and migration limitations make it risky for a production app today |
| AVFoundation + Mux HLS | Bundled local video | Acceptable for MVP phase 1 to avoid CDN setup complexity; app binary stays under 200MB by keeping videos under 30 total |

---

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| UIKit as primary framework | New app, no legacy code, no reason to accept UIKit's verbosity; SwiftUI covers all required patterns | SwiftUI throughout |
| Calling OpenAI API from iOS client directly | API key is extractable from the app binary; exposes your entire OpenAI account to abuse | Supabase Edge Functions as proxy |
| UserDefaults for auth tokens | Not encrypted; tokens appear in plain text in device backups | Keychain via KeychainAccess |
| Firebase Firestore | Document model requires denormalization for workout/exercise relationships; querying relational data (e.g., "all exercises for muscle group X in user's last 4 workouts") is painful without SQL | Supabase (PostgreSQL) |
| CocoaPods | Deprecated workflow; SPM is the standard; CocoaPods adds Ruby dependency and slower builds | Swift Package Manager |
| Combine for new async code | Async/await + Actors are the Swift 6 idiom; Combine still works but adds complexity where structured concurrency solves the same problems more readably | Swift Concurrency (async/await) |
| Third-party OpenAI Swift SDKs (e.g., `MacPaw/OpenAI`) | They lag behind OpenAI API releases; Structured Outputs and streaming endpoints have appeared in OpenAI API before SDK wrappers updated | Custom URLSession client over OpenAI REST API |
| Storing full workout history only in-memory | App crash = lost session; users expect history to persist | CoreData for local session persistence with Supabase sync |

---

## Stack Patterns by Variant

**If exercise animations are delivered as Lottie JSON (vector):**
- Use Lottie for iOS (`airbnb/lottie-ios` via SPM)
- Bundle Lottie files locally for offline access, or serve from Supabase Storage
- Significantly smaller than MP4 video; no CDN streaming required for animations
- Still use Mux for any real video content (form demos with natural motion)

**If exercise animations are MP4 video (pre-rendered):**
- Use AVFoundation + Mux HLS for all video
- Adaptive bitrate handles cellular vs WiFi automatically
- Cache recently viewed exercises with `AVAssetDownloadTask` for offline sessions

**If AI costs become unacceptable at scale:**
- Route simple conversational turns (motivation, timer questions) to GPT-4o mini
- Reserve GPT-4o calls strictly for structured plan generation
- Add a weekly plan refresh cap (e.g., 3 AI regenerations/week) to bound per-user cost
- At very high scale (100K+ active users): evaluate fine-tuning a smaller model on your workout plan corpus

**If App Store review requires Apple Sign-In:**
- Supabase Auth supports Apple Sign-In natively
- Configure Sign in with Apple in Xcode Capabilities + Supabase Auth dashboard
- Required by App Store guidelines when any third-party login is offered

---

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| RevenueCat 5.x | iOS 16+ | SDK 5.0 requires iOS 16 minimum; StoreKit 2 path only |
| Supabase Swift 2.x | iOS 15+ | SPM install; async/await throughout |
| Lottie 4.x | iOS 15+ | SPM-compatible; async rendering |
| KeychainAccess 4.x | iOS 13+ | Well-maintained, no breaking changes expected |
| SwiftData | iOS 17+ | Only use if dropping iOS 16 support; CoreData otherwise |
| SwiftUI (stable animations, NavigationStack) | iOS 16+ | NavigationStack replaces NavigationView in iOS 16; target iOS 16+ minimum for a clean SwiftUI experience |

**Recommended minimum deployment target: iOS 16.0**
This unlocks: NavigationStack, RevenueCat 5.x, stable SwiftUI sheet behavior, Swift concurrency improvements, and covers ~95%+ of active iPhone users as of 2025.

---

## Cost Model Summary

Understanding per-user AI cost is critical for subscription pricing.

| Operation | Model | Est. tokens/call | Cost/call | Frequency |
|-----------|-------|-----------------|-----------|-----------|
| Plan generation | GPT-4o | ~2,000 in + 1,500 out | ~$0.020 | Once/week |
| Adaptive adjustment | GPT-4o mini | ~1,000 in + 500 out | ~$0.0005 | 2x/session |
| Coach chat turn | GPT-4o mini | ~800 in + 300 out | ~$0.0002 | 5x/session |
| **Monthly per active user** | — | — | **~$0.15–$0.40** | 3 sessions/week |

At $9.99/month subscription, AI costs are 1.5–4% of revenue per user — very manageable. Annual plan ($79.99) further improves margins.

---

## Sources

- SwiftUI vs UIKit 2025: https://vofoxsolutions.com/swiftui-vs-uikit-2025 — HIGH confidence (multiple sources agree)
- RevenueCat SDK 5.0: https://www.revenuecat.com/blog/engineering/revenuecat-sdk-5-0-the-storekit-2-update/ — HIGH confidence (official)
- StoreKit 2 vs RevenueCat: https://theswiftk.it.com/blog/storekit-2-vs-revenuecat-ios-subscriptions — HIGH confidence
- SwiftData vs CoreData 2025: https://distantjob.com/blog/core-data-vs-swiftdata/ — MEDIUM confidence (community consensus; performance issues reported by multiple devs)
- OpenAI Structured Outputs: https://developers.openai.com/api/docs/guides/structured-outputs — HIGH confidence (official docs)
- OpenAI pricing: https://intuitionlabs.ai/articles/ai-api-pricing-comparison-grok-gemini-openai-claude — MEDIUM confidence (prices change; verify at platform.openai.com/pricing)
- Mux vs Cloudflare Stream: https://www.mux.com/compare/cloudflare-stream — HIGH confidence (verified against both official sites)
- Cloudflare R2 cost advantage: https://www.digitalapplied.com/blog/cloudflare-r2-vs-aws-s3-comparison — HIGH confidence
- Supabase Swift SDK: https://supabase.com/docs/guides/getting-started/quickstarts/ios-swiftui — HIGH confidence (official docs)
- MVVM vs TCA 2025: https://7span.com/blog/mvvm-vs-clean-architecture-vs-tca — MEDIUM confidence (community analysis)
- AVFoundation + HLS: https://www.createwithswift.com/hls-streaming-with-avkit-and-swiftui/ — HIGH confidence
- KeychainAccess security: https://www.donnywals.com/storage-options-on-ios-compared/ — HIGH confidence

---

*Stack research for: AI-powered iPhone fitness app with subscription billing*
*Researched: 2026-04-16*
