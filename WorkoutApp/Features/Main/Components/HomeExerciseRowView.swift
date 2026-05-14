import AVFoundation
import CoreData
import Supabase
import SwiftUI

// MARK: - HomeExerciseRowView
// Exercise row with thumbnail for the Home screen workout card (D-04, D-15, UI-SPEC).
// Named HomeExerciseRowView (not ExerciseRowView) to avoid collision with
// WorkoutApp/Features/PlanPreview/Components/ExerciseRowView.swift.
//
// Layout: HStack — 40x40 thumbnail | exercise name + sets label | Spacer
// Same AsyncImage phase-switch pattern as ExerciseLibraryRowView (lines 25-44),
// resized to 40x40 per D-04 spec.

struct HomeExerciseRowView: View {
    let exercise: PlannedExercise
    var onSwap: (() -> Void)? = nil

    @State private var thumbnailImage: UIImage?
    @State private var videoUrl: String?
    @State private var muxPlaybackId: String?
    @State private var showVideo = false

    private var hasVideo: Bool {
        (muxPlaybackId != nil && !(muxPlaybackId?.isEmpty ?? true)) || videoUrl != nil
    }

    private var initialPlaceholder: some View {
        Theme.surface
            .overlay {
                Text(String(exercise.exerciseName.prefix(1)).uppercased())
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
    }

    var body: some View {
        HStack(spacing: 12) {
            // MARK: - Thumbnail (tap to preview video)
            Group {
                if let img = thumbnailImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    initialPlaceholder
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .center) {
                if hasVideo {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .onTapGesture {
                guard hasVideo else { return }
                showVideo = true
            }

            // MARK: - Exercise Info
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exerciseName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)

                Text(setsLabel)
                    .font(.body)
                    .foregroundStyle(Theme.accent)
            }

            Spacer()

            if let onSwap {
                Button(action: onSwap) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 12))
                        Text("Swap")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.borderSubtle, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .task(id: exercise.exerciseName) {
            // Reset stale state when exercise changes (e.g. after swap)
            thumbnailImage = nil
            videoUrl = nil
            muxPlaybackId = nil
            await resolveVideo()
        }
        .fullScreenCover(isPresented: $showVideo) {
            VideoOverlayView(
                muxPlaybackId: muxPlaybackId ?? "",
                exerciseName: exercise.exerciseName,
                videoUrl: videoUrl
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exercise.exerciseName), \(setsLabel)")
    }

    // MARK: - Helpers

    private var setsLabel: String {
        "\(exercise.sets) x \(exercise.reps)"
    }

    /// Resolves video URL and loads thumbnail
    private func resolveVideo() async {
        let repo = ExerciseRepository.shared

        var thumbnailUrlStr: String?

        // Try CoreData first
        if let entity = try? repo.fetchByName(exercise.exerciseName) ?? repo.fetchByNameContains(exercise.exerciseName) {
            muxPlaybackId = entity.value(forKey: "muxPlaybackId") as? String
            videoUrl = entity.value(forKey: "videoUrl") as? String
            thumbnailUrlStr = entity.value(forKey: "thumbnailURL") as? String
        }

        // Supabase fallback if CoreData had no video_url
        if videoUrl == nil || thumbnailUrlStr == nil {
            struct ExerciseResult: Decodable {
                let videoUrl: String?
                let thumbnailUrl: String?
                enum CodingKeys: String, CodingKey {
                    case videoUrl = "video_url"
                    case thumbnailUrl = "thumbnail_url"
                }
            }
            if let results: [ExerciseResult] = try? await supabase
                .from("exercises")
                .select("video_url, thumbnail_url")
                .ilike("name", pattern: "%\(exercise.exerciseName)%")
                .limit(1)
                .execute()
                .value,
               let first = results.first {
                if videoUrl == nil { videoUrl = first.videoUrl }
                if thumbnailUrlStr == nil { thumbnailUrlStr = first.thumbnailUrl }
            }
        }

        // Load thumbnail from URL (fast, small JPEG)
        if let urlStr = thumbnailUrlStr,
           let url = URL(string: urlStr.replacingOccurrences(of: " ", with: "%20")),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let img = UIImage(data: data) {
            thumbnailImage = img
            return
        }

        // Fallback: generate thumbnail from video first frame
        if let urlStr = videoUrl,
           let url = URL(string: urlStr.replacingOccurrences(of: " ", with: "%20")) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 120, height: 120)
            if let (cgImage, _) = try? await generator.image(at: .zero) {
                thumbnailImage = UIImage(cgImage: cgImage)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    VStack(spacing: 0) {
        HomeExerciseRowView(exercise: PlannedExercise(
            exerciseName: "Bench Press",
            sets: 3,
            reps: "8-10",
            restSeconds: 60,
            rationale: "Primary push movement"
        ))
        Divider()
        HomeExerciseRowView(exercise: PlannedExercise(
            exerciseName: "Pull-Up",
            sets: 3,
            reps: "6-8",
            restSeconds: 90,
            rationale: "Primary pull movement"
        ))
    }
    .padding()
    .background(Theme.surface)
}
#endif
