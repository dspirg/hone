import SwiftUI

// MARK: - TrainView
// Train tab root — hosts ExerciseLibraryView (Phase 2, Plan 02).
// ExerciseLibraryView owns its own NavigationStack; do NOT wrap in another.
struct TrainView: View {
    var body: some View {
        ExerciseLibraryView()
    }
}
