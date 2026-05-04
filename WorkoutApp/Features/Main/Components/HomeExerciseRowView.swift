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
        }
        .task {
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

    /// Resolves video URL and generates thumbnail from first frame
    private func resolveVideo() async {
        let repo = ExerciseRepository.shared

        // Try CoreData first
        if let entity = try? repo.fetchByName(exercise.exerciseName) ?? repo.fetchByNameContains(exercise.exerciseName) {
            muxPlaybackId = entity.value(forKey: "muxPlaybackId") as? String
            videoUrl = entity.value(forKey: "videoUrl") as? String
        }

        // Supabase fallback if CoreData had no video_url
        if videoUrl == nil {
            struct VideoResult: Decodable {
                let videoUrl: String?
                enum CodingKeys: String, CodingKey { case videoUrl = "video_url" }
            }
            if let results: [VideoResult] = try? await supabase
                .from("exercises")
                .select("video_url")
                .ilike("name", pattern: "%\(exercise.exerciseName)%")
                .limit(1)
                .execute()
                .value,
               let url = results.first?.videoUrl {
                videoUrl = url
            }
        }

        // Generate thumbnail from video
        if let urlStr = videoUrl,
           let url = URL(string: urlStr.replacingOccurrences(of: " ", with: "%20")) {
            await generateThumbnail(from: url)
        }
    }

    private func generateThumbnail(from url: URL) async {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 120, height: 120)

        do {
            let (cgImage, _) = try await generator.image(at: .zero)
            thumbnailImage = UIImage(cgImage: cgImage)
        } catch {
            // Silent failure — placeholder stays
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
