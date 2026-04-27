import SwiftUI

// MARK: - AdaptationBannerView
// Hone adaptation banner for the Home screen (D-03, UI-SPEC).
// Shown only when a recent adaptation occurred (checked by caller via AdaptationService.lastAdjustmentDate).
//
// Layout: surface card with HoneAvatarView(diameter: 32) + VStack of title + rationale text.

struct AdaptationBannerView: View {
    /// The rationale text from the most recent AdaptationService adjustment.
    let rationale: String

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            HoneAvatarView(diameter: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hone adjusted your plan")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary)

                Text(rationale)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.borderSubtle, lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hone adjusted your plan. \(rationale)")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    AdaptationBannerView(
        rationale: "Reduced your bench press volume by 10% based on last session's difficulty rating."
    )
    .padding(.vertical)
    .background(Theme.background)
}
#endif
