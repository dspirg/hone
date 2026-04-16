# Phase 2: Exercise Library - Research

**Researched:** 2026-04-16
**Domain:** SwiftUI exercise browse/search, Mux HLS video playback with AVKit, CoreData Exercise entity, AVAssetDownloadTask offline caching, Supabase exercises table
**Confidence:** HIGH (stack is verified; one key pitfall — AVPlayerLooper HLS incompatibility — discovered and documented)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Exercise library is organized by muscle group (sectioned list) with a search bar at the top of the Train tab
- Search covers exercise name + muscle group tags (fuzzy match)
- Filter UI uses horizontal scrolling filter chips below the search bar
- Empty search state shows "No results for [query]" with 3 popular exercise suggestions
- Video plays inline in the detail view; tap-to-fullscreen is supported
- Standard AVKit controls (AVPlayerViewController) with a custom play/pause button overlay when paused
- Detail view shows: exercise name, primary muscle groups (tags), 3–5 how-to bullet steps, form tips
- Video auto-loops
- Dual taxonomy: primary muscle group (browse sections) + equipment tag (secondary filter chip)
- 8 standard muscle groups: Chest, Back, Shoulders, Arms, Core, Legs, Glutes, Full Body
- Equipment chips: Bodyweight, Dumbbells, Barbell, Machine
- Target exercise count for v1: 50–100 exercises
- Unlicensed/missing video exercises shown with metadata + placeholder thumbnail — not hidden
- Cache scope: recently viewed exercises (last 20–30) + all exercises in the user's active workout plan
- Cache size limit: 500MB max; auto-evict oldest assets when exceeded
- Cache invalidation: check for updated video versions on app launch when connected (stale-while-revalidate)
- Cache size visible in Profile/Settings

### Claude's Discretion
- Exact Mux HLS URL format and AVAssetDownloadTask implementation details
- CoreData schema for exercise entity (fields beyond the decided taxonomy)
- Supabase query structure for exercise data fetch
- Animation/transition for TrainView → ExerciseDetailView navigation
- Placeholder thumbnail design (SF Symbol or static asset)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| EXRC-01 | Every exercise in the app has a sourced/licensed animatic-style instructional video | Mux HLS delivery + AVPlayerViewController; placeholder state for unlicensed exercises; data model stores `mux_playback_id` nullable |
| EXRC-02 | User can browse and search exercises by muscle group, equipment, and difficulty | SwiftUI `.searchable()` on NavigationStack + `@Observable` ExerciseLibraryViewModel with filter state; Supabase query with `.eq`/`.in` filters |
| EXRC-03 | User can view an exercise detail page showing the video, description, muscles worked, and form tips | ExerciseDetailView with AVPlayerViewController wrapped in UIViewControllerRepresentable; CoreData Exercise entity stores all display fields |
| EXRC-04 | Workout videos are cached locally on device for offline playback during sessions | AVAssetDownloadURLSession + AVAssetDownloadTask for HLS download; CoreData stores local asset URL; 500MB eviction managed by ExerciseCacheManager |
</phase_requirements>

---

## Summary

Phase 2 introduces the exercise browse and detail experience within the existing Train tab. The primary technology challenges are: (1) integrating Mux HLS video into AVKit with auto-looping, (2) building AVAssetDownloadTask-based offline caching with 500MB eviction, and (3) creating the CoreData Exercise entity from scratch (Phase 1 did not establish a CoreData stack — no `.xcdatamodeld` exists in the project). The Supabase side is straightforward given the existing SDK and RLS patterns from Phase 1.

A critical pitfall discovered during research: **AVPlayerLooper is broken for HLS streams** — it makes multiple redundant copies of the AVPlayerItem, resulting in repeated downloads and unpredictable behavior. The correct looping pattern for HLS is `player.actionAtItemEnd = .none` combined with an `AVPlayerItemDidPlayToEndTime` notification that seeks back to `.zero`. This is a non-obvious deviation from standard AVFoundation documentation.

The MuxPlayerSwift SDK (v1.5.0) is available via SPM and extends `AVPlayerViewController` natively, offering a "Smart Cache" feature that automatically handles progressive HLS download and offline playback. Adopting the Mux SDK simplifies both online playback and the offline caching problem significantly compared to raw `AVAssetDownloadURLSession`, and should be strongly considered as the primary approach.

**Primary recommendation:** Add MuxPlayerSwift 1.5.0 via SPM. Use `AVPlayerViewController(playbackID:playbackOptions:)` for online playback with Smart Cache enabled. Use `AVAssetDownloadURLSession` as the fallback/manual approach if Mux Smart Cache proves insufficient for the 500MB limit eviction requirement.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Exercise browse/search UI | iOS Client (SwiftUI) | — | Purely presentational; filtered from local ViewModel state after initial fetch |
| Exercise data fetch | iOS Client (Supabase SDK) | Supabase (PostgreSQL) | Client fetches exercise list from Supabase on launch; no server-side rendering needed |
| Video playback (online) | iOS Client (AVKit/Mux) | CDN (Mux HLS) | AVPlayer streams from Mux's CDN via HLS; iOS handles adaptive bitrate automatically |
| Video caching (offline) | iOS Client (AVAssetDownloadTask) | Local filesystem | Downloads HLS segments to device; CoreData records local asset URL for lookup |
| Cache eviction logic | iOS Client (ExerciseCacheManager) | — | 500MB budget and recency-based eviction is client-side responsibility |
| Exercise metadata persistence | iOS Client (CoreData) | — | Exercise entity stores name, muscle group, equipment, how-to steps, mux_playback_id, local asset URL |
| Auth/RLS enforcement | Supabase (PostgreSQL) | — | exercises table uses public read-only RLS; no per-user access control needed for library |
| Thumbnail image loading | iOS Client (AsyncImage) | Mux poster frame CDN | AsyncImage loads Mux poster frame URL asynchronously; no custom networking layer |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | iOS 17+ (Xcode 26.3) | Exercise library UI, filter chips, sectioned list | Project baseline; already established in Phase 1 |
| AVKit (AVPlayerViewController) | iOS 17+ | HLS video playback with transport controls | Apple-native; AVPlayerViewController handles fullscreen, VoiceOver, and transport UI automatically |
| AVFoundation (AVAssetDownloadURLSession) | iOS 17+ | Offline HLS download and caching | Apple-native API for persisting HLS to device; no third-party alternative |
| MuxPlayerSwift | 1.5.0 | Extends AVPlayerViewController with Mux playback ID, Smart Cache, monitoring | Simplifies HLS setup; Smart Cache reduces AVAssetDownloadTask boilerplate |
| CoreData (NSPersistentContainer) | iOS 17+ | Exercise entity persistence (offline data + cache metadata) | Project decision (CLAUDE.md); SwiftData excluded due to performance issues on iOS 17 |
| Supabase Swift SDK | 2.43.1 (already installed) | Exercise data fetch from PostgreSQL | Already installed in Package.resolved; existing `supabase` singleton in SupabaseClient.swift |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| AsyncImage (SwiftUI) | iOS 15+ | Exercise thumbnail loading from Mux poster frame URL | Always — for 52x52 list thumbnails and large detail thumbnails |
| SF Symbols 5 | bundled with iOS 17 | Filter chip icons, placeholder icons, loading indicators | Always — no custom icon assets needed |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| MuxPlayerSwift SDK | Raw AVURLSession + AVPlayer with Mux `.m3u8` URL | Raw approach works but requires manually constructing `https://stream.mux.com/{playback_id}.m3u8`; no built-in Smart Cache or monitoring; more boilerplate |
| AVAssetDownloadURLSession (manual) | MuxPlayerSwift Smart Cache | Smart Cache handles single-rendition download automatically; manual AVAssetDownloadURLSession gives more control over eviction but requires more code |
| @SectionedFetchRequest (SwiftUI CoreData) | ViewModel-managed filtering | @SectionedFetchRequest ties filter logic to SwiftUI views; ViewModel approach follows established project pattern and is more testable |

**Installation:**
```bash
# In Xcode: File > Add Package > https://github.com/muxinc/mux-player-swift
# Up to Next Major from 1.0.0
```

**Version verification:** [VERIFIED: GitHub API] MuxPlayerSwift latest release: v1.5.0. [VERIFIED: Package.resolved] Supabase Swift: 2.43.1 already pinned.

---

## Architecture Patterns

### System Architecture Diagram

```
User Interaction
      |
      v
ExerciseLibraryView (TrainView replacement)
  - .searchable(text: $viewModel.searchText) on NavigationStack
  - FilterChipRow (horizontal ScrollView)
  - Sectioned List (primary muscle group as section key)
      |
      | tap row
      v
ExerciseDetailView
  - VideoPlayerView (UIViewControllerRepresentable wrapping AVPlayerViewController)
      |
      |-- Online path: stream.mux.com/{mux_playback_id}.m3u8
      |-- Offline path: local filesystem URL (from CoreData.localAssetURL)
      |
  - ExerciseMetadataSection (name, muscle tags, how-to steps, form tips)
      |
      | on view appear
      v
ExerciseCacheManager.cacheIfNeeded(exercise)
  - Check: is this exercise in active plan OR recently viewed?
  - Check: would download exceed 500MB limit? Evict oldest if so.
  - AVAssetDownloadURLSession.makeAssetDownloadTask(asset:assetTitle:assetArtworkData:options:)
  - On complete: CoreData.localAssetURL = task.urlAsset.url
      |
      v
ExerciseLibraryViewModel (@Observable)
  - Fetches exercises from Supabase on init (async)
  - Filters by activeMusclGroup + activeEquipment + searchText in-memory
  - Holds exerciseSections: [(String, [Exercise])] computed from filtered results
      |
      v
Supabase PostgreSQL (exercises table)
  - SELECT * FROM exercises (no per-user filtering — public read-only)
  - RLS: anon and authenticated roles can SELECT
      |
CoreData (local)
  - Exercise entity: id, name, primaryMuscleGroup, equipmentTag, difficulty,
    howToSteps, formTips, muxPlaybackId (nullable), localAssetURL (nullable),
    thumbnailURL, lastViewedAt
  - Used for: offline data availability, cache URL storage, recently-viewed tracking
```

### Recommended Project Structure
```
WorkoutApp/
├── Features/
│   ├── Train/
│   │   ├── ExerciseLibraryView.swift       # Replaces TrainView body; NavigationStack root
│   │   ├── ExerciseLibraryViewModel.swift  # @Observable; Supabase fetch + filter logic
│   │   ├── FilterChipRow.swift             # Horizontal ScrollView chip component
│   │   ├── ExerciseRowView.swift           # List row: thumbnail + name + muscle group
│   │   ├── ExerciseDetailView.swift        # Detail: video + metadata scrollable
│   │   ├── VideoPlayerView.swift           # UIViewControllerRepresentable wrapping AVPlayerViewController
│   │   └── ExercisePlaceholderView.swift   # Gradient card for unlicensed video
│   └── Main/
│       └── Tabs/
│           └── TrainView.swift             # Updated: hosts NavigationStack + ExerciseLibraryView
├── Core/
│   ├── Data/
│   │   ├── WorkoutApp.xcdatamodeld         # NEW: CoreData model with Exercise entity
│   │   ├── PersistenceController.swift     # NEW: NSPersistentContainer singleton
│   │   └── Exercise+CoreDataClass.swift    # Auto-generated by Xcode
│   └── Cache/
│       └── ExerciseCacheManager.swift      # NEW: AVAssetDownloadURLSession + 500MB eviction
└── supabase/
    └── migrations/
        └── YYYYMMDDHHMMSS_create_exercises.sql  # NEW: exercises table + RLS
```

### Pattern 1: NSPersistentContainer Setup (PersistenceController)
**What:** Singleton CoreData stack; established this phase since Phase 1 did not include CoreData.
**When to use:** All CoreData read/write operations go through this singleton's `viewContext`.
**Example:**
```swift
// Source: Apple CoreData docs — NSPersistentContainer pattern
import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "WorkoutApp")
        // Enable automatic lightweight migration (safe for new entities)
        let description = container.persistentStoreDescriptions.first
        description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        container.loadPersistentStores { _, error in
            if let error {
                // Fatal during development; handle gracefully in production
                fatalError("CoreData load failed: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
```

### Pattern 2: Exercise Entity Schema (CoreData)
**What:** The Exercise NSManagedObject entity — covers all fields needed for EXRC-01 through EXRC-04.
**When to use:** Define in `.xcdatamodeld` editor; fields map 1:1 to Supabase response.
```
Entity: Exercise
Attributes:
  id               UUID       (required, indexed)
  name             String     (required, indexed for search)
  primaryMuscle    String     (required, indexed — drives section headers)
  equipmentTag     String     (required — filter chips)
  difficulty       String     (required — "Beginner" / "Intermediate" / "Advanced")
  howToSteps       [String]   (store as Transformable, Array<String>)
  formTips         String     (optional, long text)
  muxPlaybackId    String?    (nullable — nil means video unlicensed)
  thumbnailURL     String?    (nullable — Mux poster frame URL)
  localAssetURL    String?    (nullable — set after AVAssetDownloadTask completes)
  lastViewedAt     Date?      (nullable — for LRU cache eviction ordering)
  syncedAt         Date       (required — for stale-while-revalidate check)
```

### Pattern 3: Supabase exercises Table + RLS Migration
**What:** Public read-only exercises table; no per-user isolation needed (content is shared).
**When to use:** Run via `supabase migration new create_exercises`.
```sql
-- Source: CITED: Supabase RLS docs + Phase 1 migration pattern
CREATE TABLE public.exercises (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name             TEXT NOT NULL,
    primary_muscle   TEXT NOT NULL
        CHECK (primary_muscle IN ('Chest','Back','Shoulders','Arms','Core','Legs','Glutes','Full Body')),
    equipment_tag    TEXT NOT NULL
        CHECK (equipment_tag IN ('Bodyweight','Dumbbells','Barbell','Machine')),
    difficulty       TEXT NOT NULL
        CHECK (difficulty IN ('Beginner','Intermediate','Advanced')),
    how_to_steps     JSONB NOT NULL DEFAULT '[]',  -- array of step strings
    form_tips        TEXT,
    mux_playback_id  TEXT,                         -- NULL = video not yet licensed
    thumbnail_url    TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for common filter operations
CREATE INDEX idx_exercises_primary_muscle ON public.exercises(primary_muscle);
CREATE INDEX idx_exercises_equipment_tag  ON public.exercises(equipment_tag);

ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

-- Public read — both anon and authenticated users can SELECT all exercises
CREATE POLICY "Exercises are publicly readable"
    ON public.exercises FOR SELECT
    TO anon, authenticated
    USING (true);

-- Only service_role (seeding scripts) can write
-- No INSERT/UPDATE/DELETE policy for client roles
```

### Pattern 4: Supabase Exercise Fetch in ViewModel
**What:** Fetch all exercises once on app launch; filter in-memory (50–100 exercises is tiny).
**When to use:** In `ExerciseLibraryViewModel.loadExercises()`.
```swift
// Source: VERIFIED via Context7 /supabase/supabase-swift
struct ExerciseDTO: Decodable {
    let id: UUID
    let name: String
    let primaryMuscle: String
    let equipmentTag: String
    let difficulty: String
    let howToSteps: [String]
    let formTips: String?
    let muxPlaybackId: String?
    let thumbnailUrl: String?
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, difficulty
        case primaryMuscle  = "primary_muscle"
        case equipmentTag   = "equipment_tag"
        case howToSteps     = "how_to_steps"
        case formTips       = "form_tips"
        case muxPlaybackId  = "mux_playback_id"
        case thumbnailUrl   = "thumbnail_url"
        case updatedAt      = "updated_at"
    }
}

// In ExerciseLibraryViewModel:
func loadExercises() async {
    isLoading = true
    defer { isLoading = false }
    do {
        let dtos: [ExerciseDTO] = try await supabase
            .from("exercises")
            .select()
            .order("name")
            .execute()
            .value
        // Upsert into CoreData; compute in-memory filter
        await upsertToCoreData(dtos)
        allExercises = dtos.map { Exercise(from: $0) }
    } catch {
        loadError = "Couldn't load exercises"
    }
}
```

### Pattern 5: Mux HLS Playback via MuxPlayerSwift
**What:** Initialize AVPlayerViewController with a Mux playback ID; Smart Cache handles offline automatically at 720p.
**When to use:** In `VideoPlayerView` (UIViewControllerRepresentable).
```swift
// Source: VERIFIED via Context7 /muxinc/mux-player-swift
import AVKit
import MuxPlayerSwift

struct VideoPlayerView: UIViewControllerRepresentable {
    let muxPlaybackId: String
    let localAssetURL: URL?  // non-nil when cached offline

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        if let localURL = localAssetURL {
            // Offline path: use local cached asset directly
            let player = AVPlayer(url: localURL)
            player.actionAtItemEnd = .none  // Loop via notification (see Pattern 6)
            let vc = AVPlayerViewController()
            vc.player = player
            context.coordinator.setupLooping(player: player)
            return vc
        } else {
            // Online path: Mux Smart Cache at 720p single rendition
            let options = PlaybackOptions(
                enableSmartCache: true,
                singleRenditionResolutionTier: .only720p
            )
            let vc = AVPlayerViewController(
                playbackID: muxPlaybackId,
                playbackOptions: options
            )
            context.coordinator.setupLooping(player: vc.player)
            return vc
        }
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        func setupLooping(player: AVPlayer?) {
            guard let player else { return }
            player.actionAtItemEnd = .none
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerDidFinish),
                name: .AVPlayerItemDidPlayToEndTime,
                object: player.currentItem
            )
        }

        @objc func playerDidFinish() {
            // Pattern 6: manual seek loop (AVPlayerLooper is broken for HLS)
            NotificationCenter.default.post(name: .AVPlayerItemDidPlayToEndTime, object: nil)
        }
    }
}
```

### Pattern 6: HLS Video Looping Without AVPlayerLooper
**What:** Manual loop via `actionAtItemEnd = .none` + seek-to-zero notification.
**When to use:** Whenever auto-looping HLS (never use AVPlayerLooper with HLS).
**Why:** AVPlayerLooper makes duplicate AVPlayerItem copies for HLS, triggering redundant network downloads and unpredictable playback behavior. [CITED: https://alegre.dev/2023/04/17/looping-videos-in-avplayer.html]
```swift
// Source: CITED: Jorge Alegre's AVPlayer looping research
player.actionAtItemEnd = .none
NotificationCenter.default.addObserver(
    forName: .AVPlayerItemDidPlayToEndTime,
    object: player.currentItem,
    queue: .main
) { [weak player] _ in
    player?.seek(to: .zero) { _ in
        player?.play()
    }
}
```

### Pattern 7: AVAssetDownloadTask for Manual Offline Caching
**What:** Fallback manual download path if Mux Smart Cache is insufficient (e.g., eviction control needed).
**When to use:** In `ExerciseCacheManager` for exercises where manual cache eviction is required.
```swift
// Source: CITED: Apple WWDC 2020 session "Discover how to download and play HLS offline"
// [https://developer.apple.com/videos/play/wwdc2020/10655/]
import AVFoundation

final class ExerciseCacheManager {
    static let shared = ExerciseCacheManager()
    private var downloadSession: AVAssetDownloadURLSession!
    private let maxCacheBytes: Int64 = 500 * 1024 * 1024  // 500MB

    private init() {
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.workoutapp.exercise-cache"
        )
        downloadSession = AVAssetDownloadURLSession(
            configuration: config,
            assetDownloadDelegate: self,
            delegateQueue: .main
        )
    }

    func downloadIfNeeded(exercise: Exercise) {
        guard exercise.localAssetURL == nil,
              let playbackId = exercise.muxPlaybackId else { return }

        // Evict oldest assets if over budget before starting new download
        evictOldestIfNeeded(requiredBytes: estimatedDownloadSize())

        let hlsURL = URL(string: "https://stream.mux.com/\(playbackId).m3u8")!
        let asset = AVURLAsset(url: hlsURL)
        let task = downloadSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: exercise.name,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 265_000]
        )
        task?.resume()
    }

    private func evictOldestIfNeeded(requiredBytes: Int64) {
        // Query CoreData: fetch exercises ordered by lastViewedAt ascending
        // Delete FileManager item at localAssetURL for oldest until headroom > requiredBytes
        // Clear localAssetURL in CoreData for evicted exercises
    }
}

extension ExerciseCacheManager: AVAssetDownloadDelegate {
    func urlSession(_ session: URLSession,
                    assetDownloadTask: AVAssetDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Store location in CoreData Exercise.localAssetURL
        // This URL is persistent across app launches (unlike temp files)
    }
}
```

### Pattern 8: Filter Chip Component
**What:** Reusable chip for muscle group and equipment filters.
**When to use:** In `FilterChipRow`.
```swift
// Source: ASSUMED — SwiftUI native pattern; no third-party needed
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color("AccentColor") : Color("CardBackground"))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.tertiaryLabel, lineWidth: 1)
                )
        }
        .frame(minHeight: 44)  // HIG touch target
        .contentShape(Rectangle())
        .accessibilityLabel("\(title) filter")
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isSelected ? "selected" : "not selected")
    }
}
```

### Anti-Patterns to Avoid
- **AVPlayerLooper with HLS:** Do NOT use `AVPlayerLooper` for looping HLS streams from Mux. It creates duplicate AVPlayerItem copies, causing repeated network downloads. Use `actionAtItemEnd = .none` + seek-to-zero notification instead. [CITED: alegre.dev]
- **Calling Supabase on every filter/search interaction:** Fetch all exercises once on launch and filter in-memory. With 50–100 exercises, network round-trips per keystroke would degrade UX and burn quota unnecessarily.
- **Storing full exercise list only in-memory:** Exercise data must persist in CoreData so the library is available offline (and for session use in Phase 4). Always upsert Supabase response to CoreData.
- **Using SwiftData instead of CoreData:** Project decision in CLAUDE.md — CoreData required; SwiftData excluded due to iOS 17 memory/performance issues.
- **Using @SectionedFetchRequest in the View:** Ties filter logic to the view layer, breaking MVVM. Use ViewModel-computed `exerciseSections: [(String, [Exercise])]` and drive the List from that.
- **Hard-coding Mux HLS URL in client code:** The URL format `https://stream.mux.com/{playback_id}.m3u8` is correct as of 2024, but store `mux_playback_id` in Supabase and construct the URL at runtime. [CITED: mux.com/docs/guides/play-your-videos]
- **Calling OpenAI or any AI API from this phase:** Phase 2 is explicitly non-AI. No AI calls in this phase.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HLS adaptive bitrate streaming | Custom URLSession downloader | AVPlayer + Mux HLS | HLS manifest parsing, bitrate switching, buffer management are extremely complex; AVFoundation handles it natively |
| Video offline download | Custom file downloader | AVAssetDownloadURLSession | HLS offline requires downloading all segment files + master playlist; API handles this correctly; FileManager alone won't work |
| Video looping | Custom timer to restart playback | `actionAtItemEnd = .none` + `.AVPlayerItemDidPlayToEndTime` | The platform provides exactly this pattern; rolling it yourself introduces timing bugs at segment boundaries |
| Thumbnail loading with placeholders | Custom URLSession image cache | SwiftUI AsyncImage | AsyncImage handles async loading, placeholder, error states, and memory caching automatically |
| Full-screen video | Custom modal overlay | AVPlayerViewController tap-to-fullscreen | `AVPlayerViewController` provides native fullscreen with device rotation, AirPlay, Picture-in-Picture support |
| Search debounce | Manual Timer-based debounce | In-memory filter on `searchText` binding | With 50–100 exercises, instant in-memory filter is imperceptible; no debounce needed at this scale |
| Cache size calculation | Walk filesystem manually | `AVAsset.assetCache?.isPlayableOffline` + `FileManager.attributesOfItem` | AVFoundation tracks what it downloaded; FileManager gives file size for eviction calculation |

**Key insight:** HLS video is one of the most complex streaming protocols. AVFoundation + Mux handle years of edge cases around adaptive bitrate, DRM, segment stitching, and offline download. Never replicate this.

---

## Common Pitfalls

### Pitfall 1: AVPlayerLooper Breaks HLS Auto-Loop
**What goes wrong:** Implement auto-loop using `AVPlayerLooper(player: queuePlayer, templateItem: item)` — video either downloads multiple times, plays erratically, or stops looping after a few iterations.
**Why it happens:** AVPlayerLooper works by queueing multiple copies of the AVPlayerItem. For HLS assets, these copies don't share state properly, causing the player to treat each copy as a fresh network stream.
**How to avoid:** Use `player.actionAtItemEnd = .none` + `NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime)` with a seek-to-zero.
**Warning signs:** Duplicate network requests to stream.mux.com in the network inspector; player shows buffering spinner at loop point.

### Pitfall 2: CoreData NSPersistentContainer Not Initialized Before First Use
**What goes wrong:** App launches, `ExerciseLibraryViewModel` calls CoreData before `PersistenceController.shared.container` finishes loading — crash on `fatalError` or silent data loss.
**Why it happens:** `container.loadPersistentStores` is async; if the container is accessed immediately in a ViewModel `init()`, the store may not be ready.
**How to avoid:** Inject `PersistenceController.shared.container.viewContext` as an `@Environment(\.managedObjectContext)` from the root view, or wait for `onAppear`/`.task` before executing CoreData fetches.
**Warning signs:** `"NSManagedObjectContext with concurrency type 'NSMainQueueConcurrencyType' cannot be used with a parent context with concurrency type 'NSPrivateQueueConcurrencyType'"` crash.

### Pitfall 3: AVAssetDownloadTask Location URL Becomes Invalid After App Restart
**What goes wrong:** Save `task.urlAsset.url` to CoreData on download completion. Next app launch, that URL is a dead path — video won't play.
**Why it happens:** The download delegate fires with a temporary URL during the download session. For persisted HLS assets, the URL stored in `didFinishDownloadingTo location:` is the permanent path on disk — but it must be stored as a bookmark or relative path, not an absolute string, as the app's sandbox container path changes across installs.
**How to avoid:** Store the URL as a security-scoped bookmark (`url.bookmarkData(options:)`) or store only the relative path within the app's `Library/` directory; reconstruct the full URL at access time using `FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)`.
**Warning signs:** Cache indicator shows "cached" but video fails to play after reinstall or OS update.

### Pitfall 4: RLS on exercises Table Blocks Unauthenticated Reads
**What goes wrong:** Supabase returns 0 rows for exercises even though data exists — exercise library appears empty.
**Why it happens:** RLS is enabled but no SELECT policy was created for the `anon` role. The anon key used before sign-in cannot read any rows.
**How to avoid:** Explicitly create `CREATE POLICY ... TO anon, authenticated USING (true)` — both roles need it. Test with the Supabase SQL editor using `SET role anon;` before reading.
**Warning signs:** Empty exercise list in the app; Supabase SQL editor returns rows but iOS app returns none.

### Pitfall 5: Mux Smart Cache Ignores Custom 500MB Eviction Budget
**What goes wrong:** Mux Smart Cache downloads video but the 500MB limit isn't enforced — device fills up.
**Why it happens:** MuxPlayerSwift Smart Cache manages its own internal budget; the app-level 500MB eviction logic is separate. If both are running, they can conflict.
**How to avoid:** Either (a) rely on Mux Smart Cache only and expose a "Clear video cache" button in Profile settings (simplest), or (b) disable Mux Smart Cache and use raw `AVAssetDownloadURLSession` with full manual eviction. Do not use both simultaneously.
**Warning signs:** Device storage increases beyond expected 500MB after caching many exercises.

### Pitfall 6: searchable() Modifier Placement Collapses Filter Chips Unexpectedly
**What goes wrong:** `.searchable()` modifier placed on the `List` instead of the `NavigationStack` — filter chips may not collapse when the search field is active, or the search bar doesn't appear in the navigation bar.
**Why it happens:** `.searchable()` propagates through the NavigationStack to place the search bar in the navigation area. Placing it on the List bypasses this mechanism.
**How to avoid:** Always apply `.searchable(text:)` on the `NavigationStack` that wraps `ExerciseLibraryView`, not on the `List` or `ScrollView` inside it.
**Warning signs:** Search bar appears inline below content rather than in the navigation bar; filter chip row does not auto-collapse on search activation.

---

## Code Examples

### Exercise List with Sectioned Data and Search

```swift
// Source: VERIFIED via Context7 /websites/developer_apple_swiftui
// ExerciseLibraryView — sectioned list with .searchable on NavigationStack
NavigationStack {
    List {
        ForEach(viewModel.exerciseSections, id: \.0) { section, exercises in
            Section(header: Text(section).textCase(.uppercase)) {
                ForEach(exercises) { exercise in
                    NavigationLink {
                        ExerciseDetailView(exercise: exercise)
                    } label: {
                        ExerciseRowView(exercise: exercise)
                    }
                    .accessibilityLabel("\(exercise.name), \(exercise.primaryMuscle)")
                }
            }
        }
    }
    .listStyle(.plain)
    .searchable(text: $viewModel.searchText, prompt: "Search exercises")
    .refreshable {
        await viewModel.loadExercises()
    }
    .overlay {
        if viewModel.isLoading {
            ProgressView()
        } else if viewModel.exerciseSections.isEmpty && !viewModel.searchText.isEmpty {
            // Empty search result state per UI-SPEC
            VStack(spacing: 8) {
                Text("No results for \"\(viewModel.searchText)\"")
                    .font(.title2).fontWeight(.semibold)
                Text("Try a different name or muscle group.")
                    .font(.body).foregroundStyle(.secondary)
            }
        }
    }
    .navigationTitle("Exercises")
}
```

### AsyncImage for Exercise Thumbnail

```swift
// Source: VERIFIED via Context7 /websites/developer_apple_swiftui
AsyncImage(url: URL(string: exercise.thumbnailURL ?? "")) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fill)
} placeholder: {
    Color("CardBackground")
        .overlay {
            Image(systemName: "dumbbell")
                .font(.body)
                .foregroundStyle(.tertiaryLabel)
        }
}
.frame(width: 52, height: 52)
.cornerRadius(8)
.clipped()
```

### Supabase Filter Query (if server-side filtering preferred for large libraries)

```swift
// Source: VERIFIED via Context7 /supabase/supabase-swift
// Only needed if exercise count grows beyond ~500 (in-memory filter breaks down)
let exercises: [ExerciseDTO] = try await supabase
    .from("exercises")
    .select()
    .eq("primary_muscle", value: selectedMuscleGroup)
    .eq("equipment_tag", value: selectedEquipment)
    .ilike("name", pattern: "%\(searchText)%")
    .execute()
    .value
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| @ObservableObject + @Published | @Observable macro | Swift 5.9 / iOS 17 (2023) | Established in Phase 1 — all ViewModels use @Observable |
| Combine publishers for async work | Swift Concurrency (async/await, Task) | Swift 5.5 / iOS 15 (2021) | Established in Phase 1 — use Task { } for all async calls |
| AVPlayerLooper for looping video | actionAtItemEnd + seek-to-zero notification | Always wrong for HLS | Critical: do NOT use AVPlayerLooper with HLS |
| NavigationView | NavigationStack | iOS 16 (2022) | Already established in Phase 1 — use NavigationStack |
| @FetchRequest in View | @Observable ViewModel with NSFetchRequest | Project pattern | Keeps filter logic testable and outside View layer |
| SwiftData | CoreData | Project decision (CLAUDE.md) | SwiftData excluded; CoreData required for this phase |

**Deprecated/outdated:**
- `AVPlayerLooper` for HLS streams: technically still exists but functionally broken for HLS; use manual loop pattern
- `@SectionedFetchRequest`: Works but violates MVVM by putting fetch logic in the View; avoid for this project

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | In-memory filtering of 50–100 exercises is fast enough that no debounce or server-side filter is needed | Architecture Patterns | Low risk — even 1,000 exercises filters in <1ms in Swift; would only matter at 10,000+ |
| A2 | Mux Smart Cache at `.only720p` single rendition produces file sizes of ~50–100MB per exercise video (typical short animatic) | Offline Caching pattern | Medium risk — actual sizes depend on video duration; if exercises are longer than ~3 min at 720p, 500MB fills faster than expected |
| A3 | The `exercises` table is populated by the development team (seeding scripts) before the app ships; no in-app content management UI is needed in Phase 2 | Standard Stack | Low risk — confirmed by CONTEXT.md scope (no CMS UI in scope) |
| A4 | MuxPlayerSwift Smart Cache is sufficient for the recently-viewed + active-plan caching strategy without manual AVAssetDownloadTask | Don't Hand-Roll | Medium risk — Smart Cache documentation doesn't detail eviction policies; may need to supplement with manual tracking |

---

## Open Questions

1. **Mux Smart Cache vs. Manual AVAssetDownloadTask**
   - What we know: MuxPlayerSwift 1.5.0 has a Smart Cache feature for single-rendition offline playback; manual AVAssetDownloadURLSession gives full eviction control
   - What's unclear: Does Mux Smart Cache expose an API to query total cached size or evict specific assets? The SDK docs don't detail this.
   - Recommendation: Start with Mux Smart Cache (less code). If size visibility in Profile Settings cannot be implemented via Smart Cache introspection, fall back to manual AVAssetDownloadURLSession for the recently-viewed tier only.

2. **CoreData model versioning from the start**
   - What we know: This is the first CoreData model (`.xcdatamodeld`) in the project; Phase 1 had no CoreData
   - What's unclear: Should the model be versioned from v1 to allow future lightweight migrations, or start unversioned?
   - Recommendation: Create a versioned model (`WorkoutApp.xcdatamodeld` with a `WorkoutApp 1.xcdatamodel` inside) from the start. Zero cost now; prevents migration pain in Phase 4 when Session entities are added.

3. **Mux exercise video asset upload workflow**
   - What we know: Mux playback IDs are stored in the `exercises` table; the upload/encoding workflow happens outside the app
   - What's unclear: Whether video assets are available for seeding before Phase 2 executes (CONTEXT.md notes video content sourcing is a known blocker)
   - Recommendation: Phase 2 must handle `mux_playback_id = NULL` gracefully (placeholder state); the placeholder path is already designed. Phase execution is not blocked — seeding with placeholder data is sufficient.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | All iOS development | Yes | Xcode 26.3 (build 17C529) | — |
| Supabase CLI | Migration deployment | Yes | 2.84.2 | — |
| Supabase Swift SDK | Exercise data fetch | Yes (pinned) | 2.43.1 | — |
| MuxPlayerSwift | HLS video playback | No (not yet installed) | 1.5.0 available via SPM | Raw AVPlayer + Mux m3u8 URL (more boilerplate) |
| Mux account + playback IDs | EXRC-01, EXRC-03 | Unknown (external dependency) | — | Placeholder gradient card; app works without real videos |

**Missing dependencies with no fallback:**
- None that block execution. The Mux SDK install is a Wave 0 task. App works with placeholder data while Mux account/videos are being sourced.

**Missing dependencies with fallback:**
- Mux playback IDs: exercise rows where `mux_playback_id` is NULL fall through to the placeholder gradient card. Phase can complete without real video content.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (bundled with Xcode 26.3) |
| Config file | `WorkoutApp/Tests/` — existing test target from Phase 1 |
| Quick run command | `xcodebuild test -project WorkoutApp.xcodeproj -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Full suite command | Same (single scheme) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EXRC-01 | Exercises with null mux_playback_id show placeholder view (not crash) | Unit | `xcodebuild test ... -only-testing ExerciseLibraryTests/testPlaceholderRendersForNilPlaybackId` | No — Wave 0 |
| EXRC-02 | Filter by muscle group returns only matching exercises | Unit | `xcodebuild test ... -only-testing ExerciseLibraryTests/testMuscleGroupFilterReducesSections` | No — Wave 0 |
| EXRC-02 | Search by name returns fuzzy match results | Unit | `xcodebuild test ... -only-testing ExerciseLibraryTests/testSearchReturnsPartialNameMatch` | No — Wave 0 |
| EXRC-02 | "All" chip clears active filters | Unit | `xcodebuild test ... -only-testing ExerciseLibraryTests/testAllChipClearsFilters` | No — Wave 0 |
| EXRC-03 | Detail view shows exercise name, primary muscle, how-to steps | UI / Manual | Manual on simulator | n/a |
| EXRC-04 | Cached exercise plays when network is disabled | Integration / Manual | Manually disable network in simulator + verify playback | n/a — Manual only (simulator network toggle) |
| EXRC-04 | Cache eviction triggers when 500MB limit is exceeded | Unit | `xcodebuild test ... -only-testing ExerciseCacheTests/testEvictsOldestWhenOverBudget` | No — Wave 0 |

### Sampling Rate
- **Per task commit:** `xcodebuild test -project WorkoutApp.xcodeproj -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing ExerciseLibraryTests`
- **Per wave merge:** Full suite
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `WorkoutApp/Tests/ExerciseLibraryTests.swift` — covers EXRC-01, EXRC-02 filter/search logic
- [ ] `WorkoutApp/Tests/ExerciseCacheTests.swift` — covers EXRC-04 cache eviction budget

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | Phase 1 handles auth; exercises table is public read |
| V3 Session Management | No | No session state changes in this phase |
| V4 Access Control | Yes (minimal) | Supabase RLS: exercises table SELECT allowed for anon + authenticated; no write access from client |
| V5 Input Validation | Yes | Search text is never sent to Supabase as a raw query in the primary path (in-memory filter); if Supabase query path used, `.ilike` operator parameterizes safely — no SQL injection vector |
| V6 Cryptography | No | No cryptographic operations; no new secrets |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Mux playback ID exposure in app binary | Information Disclosure | mux_playback_id stored in Supabase, fetched at runtime — not hard-coded in binary; signed URLs not required for public exercise content |
| Local HLS segment file access by other apps | Elevation of Privilege | AVAssetDownloadTask stores files in app's sandboxed `Library/` directory; not accessible by other apps |
| Cache poisoning via URL manipulation | Tampering | URLs are constructed from `mux_playback_id` fetched from Supabase (server-controlled); user cannot inject arbitrary URLs |

---

## Sources

### Primary (HIGH confidence)
- Context7 `/muxinc/mux-player-swift` — Smart Cache, SPM installation, AVPlayerViewController extension, monitoring cleanup
- Context7 `/supabase/supabase-swift` — database query filters (`.eq`, `.ilike`, `.in`), async/await patterns
- Context7 `/websites/developer_apple_swiftui` — `.searchable()` modifier, `AsyncImage`, sectioned `List`, `ForEach` with sections
- Context7 `/websites/developer_apple_coredata` — `NSPersistentContainer`, lightweight migration options
- GitHub API — MuxPlayerSwift latest: v1.5.0; Supabase Swift latest: v2.43.1

### Secondary (MEDIUM confidence)
- [Mux — Play Your Videos guide](https://www.mux.com/docs/guides/play-your-videos) — HLS URL format `https://stream.mux.com/{playback_id}.m3u8`
- [Apple WWDC 2020 — Discover how to download and play HLS offline](https://developer.apple.com/videos/play/wwdc2020/10655/) — AVAssetDownloadURLSession delegate pattern
- [Supabase RLS docs](https://supabase.com/docs/guides/database/postgres/row-level-security) — public read-only policy pattern for shared content tables
- [Apple SectionedFetchRequest docs](https://developer.apple.com/documentation/SwiftUI/SectionedFetchRequest) — confirmed but not used (ViewModel pattern preferred)

### Tertiary (LOW confidence — flagged as ASSUMED)
- AVAssetDownloadTask bookmark storage pattern for sandbox URL persistence — from community documentation, not verified against Apple official docs directly

---

## Project Constraints (from CLAUDE.md)

- iOS only — no cross-platform considerations
- SwiftUI throughout — no UIKit as primary framework (UIViewControllerRepresentable for AVPlayerViewController is the sole UIKit bridge)
- Swift 6 + async/await — no Combine for new async code
- MVVM vanilla (@Observable) — no TCA, no external state management
- CoreData (not SwiftData) — iOS 17 SwiftData performance issues documented
- SPM only — no CocoaPods, no Carthage
- Supabase (not Firebase) — relational data model
- Mux for video hosting and HLS delivery (not Cloudflare Stream)
- AVFoundation + AVKit for playback (not third-party video players)
- AVAssetDownloadTask for offline caching
- Never call OpenAI directly from iOS client — proxy via Supabase Edge Functions (not relevant in Phase 2)
- Never store sensitive tokens in UserDefaults — Keychain via KeychainAccess (not relevant in Phase 2)
- No CocoaPods

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified via Context7, Package.resolved, and GitHub releases API
- Architecture: HIGH — follows established Phase 1 MVVM patterns; no novel patterns introduced
- Video looping pitfall: HIGH — directly cited from community research + confirmed by AVFoundation behavior description
- Offline caching: MEDIUM — AVAssetDownloadURLSession is well-documented; Mux Smart Cache eviction control is not fully documented
- CoreData schema: MEDIUM — field selection is reasonable but schema will need adjustment when Phase 4 (sessions) adds related entities

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (stable APIs; Mux SDK and Supabase Swift release frequently — verify versions at planning time)
