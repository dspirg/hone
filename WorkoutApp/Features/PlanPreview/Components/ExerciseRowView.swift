import AVFoundation
import CoreData
import Supabase
import SwiftUI

// MARK: - ExerciseRowView
// Renders a single planned exercise inside a WorkoutDayCardView.
// Shows a leading 52x52 thumbnail (resolved from CoreData by name), exercise name,
// sets/reps/rest, and AI rationale coach note (D-07, AIPL-02).
// Tapping the thumbnail (when muxPlaybackId is available) presents VideoOverlayView fullscreen.
//
// UI-SPEC: ExerciseRowView contract
// Typography: exercise name = .subheadline semibold, sets/reps = .subheadline secondary,
//             rationale = .subheadline tertiary with quote.opening icon.
// Accessibility: .accessibilityElement(children: .combine) — VoiceOver reads entire row
//                as one element: "[name], [sets] sets, [reps] reps, [rest]s rest. Why: [rationale]"

struct ExerciseRowView: View {
    let exercise: PlannedExercise

    @State private var thumbnailImage: UIImage?
    @State private var videoUrl: String?
    @State private var muxPlaybackId: String?
    @State private var showVideo = false

    var body: some View {
        HStack(spacing: 12) {
            // MARK: Thumbnail (52x52, tap to preview video)
            Group {
                if let img = thumbnailImage {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Theme.surface
                        .overlay {
                            Image(systemName: "dumbbell")
                                .font(.body)
                                .foregroundStyle(Color(UIColor.tertiaryLabel))
                        }
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .center) {
                if videoUrl != nil || muxPlaybackId != nil {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .onTapGesture {
                guard videoUrl != nil || muxPlaybackId != nil else { return }
                showVideo = true
            }
            .fullScreenCover(isPresented: $showVideo) {
                VideoOverlayView(
                    muxPlaybackId: muxPlaybackId ?? "",
                    exerciseName: exercise.exerciseName,
                    videoUrl: videoUrl
                )
            }

            // MARK: Exercise Info
            VStack(alignment: .leading, spacing: 4) {  // xs (4pt) spacing between lines
                // Exercise name — .subheadline semibold (15pt, 600)
                Text(exercise.exerciseName)
                    .font(.subheadline.weight(.semibold))

                // Sets/reps/rest — .subheadline regular (15pt, 400), .secondary color
                // Format: "4 sets × 8-10 — 90s rest"
                Text("\(exercise.sets) sets \u{00D7} \(exercise.reps) \u{2014} \(exercise.restSeconds)s rest")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // AI rationale — .subheadline regular (15pt, 400), .tertiary color (AIPL-02 / D-07)
                // quote.opening SF Symbol at 11pt as inline leading decoration
                HStack(alignment: .firstTextBaseline, spacing: 4) {  // xs gap
                    Image(systemName: "quote.opening")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                    Text("Why: \(exercise.rationale)")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16)  // md (16pt) inside card
        .padding(.vertical, 8)     // sm (8pt) top and bottom
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        // VoiceOver will read: "[exerciseName], [sets] sets × [reps] — [restSeconds]s rest. Why: [rationale]"
        .task {
            await resolveThumbnail()
        }
    }

    // MARK: - Thumbnail Resolution

    @MainActor
    private func resolveThumbnail() async {
        let repo = ExerciseRepository.shared

        if let entity = try? repo.fetchByName(exercise.exerciseName) ?? repo.fetchByNameContains(exercise.exerciseName) {
            muxPlaybackId = entity.value(forKey: "muxPlaybackId") as? String
            videoUrl = entity.value(forKey: "videoUrl") as? String
        }

        // Supabase fallback
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
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 160, height: 160)
            if let (cgImage, _) = try? await generator.image(at: .zero) {
                thumbnailImage = UIImage(cgImage: cgImage)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ExerciseRowView(exercise: PlannedExercise(
        exerciseName: "Barbell Back Squat",
        sets: 4,
        reps: "6-8",
        restSeconds: 120,
        rationale: "Primary lower body compound movement targeting quads, glutes, and hamstrings"
    ))
    .background(Theme.surface)
}
#endif
