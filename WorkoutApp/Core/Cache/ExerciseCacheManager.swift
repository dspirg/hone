import AVFoundation
import CoreData
import Foundation

// MARK: - ExerciseCacheManager
// Manages local HLS video cache for exercise videos. Two-layer strategy:
//
// Layer 1 (Playback): Mux Smart Cache (via VideoPlayerView) handles progressive online caching
//   at 720p single rendition automatically during playback. This runs inside AVPlayerViewController.
//
// Layer 2 (Budget enforcement): ExerciseCacheManager tracks locally cached HLS files, calculates
//   total size, and evicts oldest exercises (by lastViewedAt) when exceeding the 500MB budget.
//   This satisfies T-02-09 (DoS mitigation via storage cap).
//
// Option A pattern per 02-PLAN.md: Smart Cache for playback convenience + manual eviction tracking.
// Do NOT enable AVAssetDownloadURLSession alongside Smart Cache — they conflict on cache budget
// (Pitfall 5 in 02-RESEARCH.md).
//
// @MainActor: All CoreData access goes through PersistenceController.shared (main actor isolated),
// so ExerciseCacheManager is also pinned to the main actor for consistency.
//
// Requirements: EXRC-04
// Threat: T-02-09 — 500MB cap prevents device storage exhaustion
// Pitfall 3: Store relative path within Library/ (not absolute) — sandbox container path changes
//            across installs. Reconstruct full URL at access time.

@MainActor
final class ExerciseCacheManager {
    static let shared = ExerciseCacheManager()

    // MARK: - Constants

    /// 500MB maximum cache budget (EXRC-04, T-02-09)
    let maxCacheBytes: Int64 = 500 * 1_024 * 1_024

    /// Reserved headroom for a new download before eviction runs
    private let reservedDownloadBytes: Int64 = 50 * 1_024 * 1_024

    // MARK: - Active Download Tracking
    // Both the session and its delegate must be retained strongly until the download completes.
    // AVAssetDownloadURLSession cancels in-flight tasks if the session is deallocated.
    // Keyed by exerciseId so each exercise has at most one active download at a time.
    private var activeSessions: [UUID: AVAssetDownloadURLSession] = [:]
    private var activeDelegates: [UUID: DownloadDelegate] = [:]

    private init() {}

    // MARK: - Cache Size

    /// Calculates total size of locally cached exercise video assets.
    /// Scans all CoreData Exercise entities with a non-nil localAssetURL.
    /// Falls back gracefully if a file is missing from disk (returns 0 for that entry).
    func currentCacheSize() -> Int64 {
        let context = PersistenceController.shared.container.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "localAssetURL != nil")

        guard let entities = try? context.fetch(request) else { return 0 }

        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first

        var totalBytes: Int64 = 0
        for entity in entities {
            guard let relativePath = entity.value(forKey: "localAssetURL") as? String else { continue }
            let fileURL: URL
            if let base = libraryURL {
                fileURL = base.appendingPathComponent(relativePath)
            } else {
                fileURL = URL(fileURLWithPath: relativePath)
            }

            if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                totalBytes += size
            }
        }
        return totalBytes
    }

    /// Human-readable cache size string for display in ProfileView.
    /// Example: "42.3 MB", "1.2 GB"
    func formattedCacheSize() -> String {
        ByteCountFormatter.string(fromByteCount: currentCacheSize(), countStyle: .file)
    }

    // MARK: - Eviction

    /// Evicts the oldest (by lastViewedAt) cached exercises until there is headroom for a new download.
    /// Called by downloadIfNeeded(_:muxPlaybackId:) before starting a new background download.
    ///
    /// - Parameter requiredBytes: minimum bytes to free before returning (default 50MB)
    func evictOldestIfNeeded(requiredBytes: Int64 = 50 * 1_024 * 1_024) {
        let context = PersistenceController.shared.container.viewContext

        while currentCacheSize() + requiredBytes > maxCacheBytes {
            // Fetch the exercise with the oldest lastViewedAt that has a local asset
            let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
            request.predicate = NSPredicate(format: "localAssetURL != nil")
            request.sortDescriptors = [
                // Treat nil lastViewedAt as oldest — evict first
                NSSortDescriptor(key: "lastViewedAt", ascending: true)
            ]
            request.fetchLimit = 1

            guard let entities = try? context.fetch(request),
                  let oldest = entities.first,
                  let relativePath = oldest.value(forKey: "localAssetURL") as? String else {
                break // Nothing more to evict
            }

            // Delete physical file from disk
            let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first
            let fileURL: URL
            if let base = libraryURL {
                fileURL = base.appendingPathComponent(relativePath)
            } else {
                fileURL = URL(fileURLWithPath: relativePath)
            }

            // Non-fatal: if file is already missing, still clear the CoreData reference
            try? FileManager.default.removeItem(at: fileURL)

            // Clear the CoreData localAssetURL reference
            oldest.setValue(nil, forKey: "localAssetURL")
            do {
                try context.save()
            } catch {
                // Cannot persist eviction — break to avoid infinite loop.
                // Log to analytics in production.
                context.rollback()
                break
            }
        }
    }

    // MARK: - Download

    /// Triggers a background HLS download for an exercise if not already cached.
    /// Checks CoreData for an existing localAssetURL; skips if already cached.
    /// Runs eviction before starting a new download to stay within the 500MB budget.
    ///
    /// Note: This uses manual AVAssetDownloadURLSession (not Mux Smart Cache) for
    /// exercises that need explicit download tracking (e.g., exercises in the user's
    /// active workout plan). For general playback, Mux Smart Cache in VideoPlayerView
    /// handles caching automatically.
    func downloadIfNeeded(exerciseId: UUID, muxPlaybackId: String) {
        let context = PersistenceController.shared.container.viewContext

        // Check CoreData: if localAssetURL already set, skip
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
        request.fetchLimit = 1

        guard let entities = try? context.fetch(request),
              let entity = entities.first else { return }

        // Already cached — no download needed
        if entity.value(forKey: "localAssetURL") as? String != nil { return }

        // Enforce budget before starting download
        evictOldestIfNeeded(requiredBytes: reservedDownloadBytes)

        // Create AVURLAsset from Mux HLS URL — guard against malformed playback IDs
        guard let hlsURL = URL(string: "https://stream.mux.com/\(muxPlaybackId).m3u8") else {
            // Invalid playback ID — skip download silently, log to analytics in production
            return
        }
        let asset = AVURLAsset(url: hlsURL)

        // Build background URLSession configuration
        let config = URLSessionConfiguration.background(
            withIdentifier: "com.workoutapp.exercise-cache.\(exerciseId.uuidString)"
        )
        let delegate = DownloadDelegate(exerciseId: exerciseId)
        let downloadSession = AVAssetDownloadURLSession(
            configuration: config,
            assetDownloadDelegate: delegate,
            delegateQueue: .main
        )

        // Retain both strongly so the session (and its in-flight task) survives until the
        // delegate callback fires. Without this the session is released immediately on return,
        // cancelling the download silently. Cleaned up in DownloadDelegate.didFinishDownloadingTo.
        activeSessions[exerciseId] = downloadSession
        activeDelegates[exerciseId] = delegate

        // Start download task (low-bitrate rendition to minimise file size)
        guard let task = downloadSession.makeAssetDownloadTask(
            asset: asset,
            assetTitle: exerciseId.uuidString,
            assetArtworkData: nil,
            options: [AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 265_000]
        ) else { return }

        task.resume()
    }

    // MARK: - Clear All

    /// Deletes all cached video files and clears localAssetURL from CoreData.
    /// Intended for a "Clear video cache" button in ProfileView (future iteration).
    func clearAllCache() {
        let context = PersistenceController.shared.container.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
        request.predicate = NSPredicate(format: "localAssetURL != nil")

        guard let entities = try? context.fetch(request) else { return }

        let libraryURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first

        for entity in entities {
            if let relativePath = entity.value(forKey: "localAssetURL") as? String {
                let fileURL: URL
                if let base = libraryURL {
                    fileURL = base.appendingPathComponent(relativePath)
                } else {
                    fileURL = URL(fileURLWithPath: relativePath)
                }
                try? FileManager.default.removeItem(at: fileURL)
            }
            entity.setValue(nil, forKey: "localAssetURL")
        }

        try? context.save()
    }
}

// MARK: - DownloadDelegate
// Handles AVAssetDownloadURLSession completion callbacks.
// Stores the downloaded asset location as a RELATIVE path within Library/ (Pitfall 3).
// Absolute sandbox container paths change across installs and OS updates.
//
// Not @MainActor — AVAssetDownloadDelegate callbacks arrive on the delegateQueue (.main),
// but the protocol itself is nonisolated. We hop to MainActor explicitly for CoreData writes.

private final class DownloadDelegate: NSObject, AVAssetDownloadDelegate, @unchecked Sendable {
    private let exerciseId: UUID

    init(exerciseId: UUID) {
        self.exerciseId = exerciseId
    }

    func urlSession(
        _ session: URLSession,
        assetDownloadTask: AVAssetDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Compute relative path within Library/ to avoid sandbox path invalidation (Pitfall 3)
        let libraryURL = FileManager.default.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first

        let relativePath: String
        if let base = libraryURL, location.path.hasPrefix(base.path) {
            // Strip Library/ prefix to store only the relative portion
            let strippedPath = String(location.path.dropFirst(base.path.count))
            // Remove leading "/" if present
            relativePath = strippedPath.hasPrefix("/") ? String(strippedPath.dropFirst()) : strippedPath
        } else {
            // Fallback: store full path (may break after reinstall — log as known limitation)
            relativePath = location.path
        }

        // Update CoreData Exercise entity with relative path — must run on main actor
        let exerciseId = self.exerciseId
        Task { @MainActor in
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<NSManagedObject>(entityName: "Exercise")
            request.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
            request.fetchLimit = 1

            if let entity = try? context.fetch(request).first {
                entity.setValue(relativePath, forKey: "localAssetURL")
                try? context.save()
            }

            // Release the retained session and delegate now that the download is complete
            ExerciseCacheManager.shared.activeSessions.removeValue(forKey: exerciseId)
            ExerciseCacheManager.shared.activeDelegates.removeValue(forKey: exerciseId)
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // Silently ignore download errors — video will be re-downloaded on next view
        // In production: log error to analytics for monitoring
    }
}
