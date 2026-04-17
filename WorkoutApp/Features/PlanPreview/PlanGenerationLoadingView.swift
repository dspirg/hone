import SwiftUI
import UIKit

// MARK: - PlanGenerationLoadingView
// Full-screen loading overlay shown during AI plan generation.
// Shows a pulsing 3-ring animation with 3-phase cycling copy (D-15).
// Falls back to system ProgressView when Reduce Motion is enabled (accessibility).
// Shows error overlay with Try Again button after second failure (D-16, D-17).
//
// UI-SPEC: PlanGenerationLoadingView contract
// Requirements: ONBD-03

struct PlanGenerationLoadingView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    let errorMessage: String?
    let onRetry: () -> Void

    // Cycling text state
    @State private var currentPhase: Int = 0
    @State private var outerRotation: Double = 0
    @State private var middleRotation: Double = 0
    @State private var cycleTimer: Timer?

    // 3 phases per D-15 / UI-SPEC Copywriting Contract
    private let phases = [
        "Analyzing your goals\u{2026}",
        "Building your schedule\u{2026}",
        "Selecting your exercises\u{2026}"
    ]

    var body: some View {
        ZStack {
            Color("AppBackground").ignoresSafeArea()

            if let error = errorMessage {
                errorOverlay(message: error)
            } else {
                loadingContent
            }
        }
        .onAppear {
            startCycling()
        }
        .onDisappear {
            cycleTimer?.invalidate()
            cycleTimer = nil
        }
    }

    // MARK: - Loading Content

    private var loadingContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated loading indicator — falls back to ProgressView for Reduce Motion
            if reduceMotion {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color("AccentColor"))
                    .accessibilityHidden(false)
                    .accessibilityLabel("Loading your plan")
            } else {
                pulsingRings
                    .accessibilityHidden(true)  // decorative animation
            }

            Spacer().frame(height: 24)  // lg gap between rings and text

            // Cycling phase text — uses .id() to trigger opacity transition on change
            Text(phases[currentPhase])
                .font(.title.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .id(currentPhase)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.4), value: currentPhase)

            Spacer()
            Spacer()  // bottom spacer larger than top to visually center content in upper half
        }
    }

    // MARK: - Pulsing Rings (3 concentric circles per UI-SPEC)

    private var pulsingRings: some View {
        ZStack {
            // Outer ring: 80pt diameter, 3pt stroke, 100% opacity, clockwise
            Circle()
                .stroke(Color("AccentColor").opacity(1.0), lineWidth: 3)
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(outerRotation))

            // Middle ring: 56pt, 2pt stroke, 60% opacity, counter-clockwise
            Circle()
                .stroke(Color("AccentColor").opacity(0.6), lineWidth: 2)
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(-middleRotation))

            // Inner ring: 32pt, 2pt stroke, 30% opacity, same direction as outer
            Circle()
                .stroke(Color("AccentColor").opacity(0.3), lineWidth: 2)
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(outerRotation))
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                outerRotation = 360
            }
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                middleRotation = 360
            }
        }
    }

    // MARK: - Error Overlay (D-16 / D-17)

    private func errorOverlay(message: String) -> some View {
        let isNetworkError = message.lowercased().contains("connection") ||
                             message.lowercased().contains("network") ||
                             message.lowercased().contains("offline")

        return VStack(spacing: 16) {
            Spacer()

            // Context-sensitive SF Symbol icon
            Image(systemName: isNetworkError ? "wifi.slash" : "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            // Heading
            Text(isNetworkError ? "Check your connection" : "Something went wrong")
                .font(.title2.weight(.semibold))

            // Body text
            Text(isNetworkError
                ? "Make sure you're connected to the internet, then try again."
                : "We couldn't generate your plan. Tap below to try again.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            // Try Again button — 52pt height, 12pt corner radius, full-width accent fill
            Button(action: onRetry) {
                Text("Try Again")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color("AccentColor"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .accessibilityLabel("Try Again")
            .accessibilityHint("Retries plan generation.")

            Spacer()
            Spacer()
        }
    }

    // MARK: - Cycling Timer

    private func startCycling() {
        cycleTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            Task { @MainActor in
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentPhase = (currentPhase + 1) % phases.count
                }
                // Accessibility announcement when phase text changes (D-15)
                UIAccessibility.post(notification: .announcement, argument: phases[currentPhase])
            }
        }
    }
}
