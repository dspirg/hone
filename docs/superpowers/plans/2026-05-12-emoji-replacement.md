# Emoji Replacement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all 9 emoji icons with SF Symbols inside styled gradient containers for a polished, consistent look.

**Architecture:** Refactor `OnboardingHeroIcon` from emoji text to SF Symbol + gradient. Update `DifficultyRating` model to provide icon/color data instead of emoji strings. Swap inline emoji text with SF Symbol images in `WeekStreakBar` and `SessionSummaryView`.

**Tech Stack:** SwiftUI, SF Symbols, `LinearGradient`

**Spec:** `docs/superpowers/specs/2026-05-12-emoji-replacement-design.md`

---

### Task 1: Refactor OnboardingHeroIcon component

**Files:**
- Modify: `WorkoutApp/Features/Onboarding/Components/OnboardingHeroIcon.swift`

The component currently accepts a `symbol: String` (emoji) and renders it as `Text`. Refactor to accept an SF Symbol name and gradient colors, rendering as `Image(systemName:)` inside a gradient rounded rectangle.

- [ ] **Step 1: Update OnboardingHeroIcon to accept new parameters**

Replace the entire file content:

```swift
import SwiftUI

struct OnboardingHeroIcon: View {
    let iconName: String
    let gradient: [Color]
    @State private var scale: CGFloat = 0.8

    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 28, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 72, height: 72)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: gradient.first?.opacity(0.35) ?? .clear, radius: 12)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    scale = 1.0
                }
            }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild build -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`

Expected: Build will fail because all 6 card views still pass the old `symbol:` parameter. That's expected — we fix those next.

- [ ] **Step 3: Commit**

```bash
git add WorkoutApp/Features/Onboarding/Components/OnboardingHeroIcon.swift
git commit -m "refactor: update OnboardingHeroIcon to accept SF Symbol + gradient"
```

---

### Task 2: Update all 6 onboarding card views

**Files:**
- Modify: `WorkoutApp/Features/Onboarding/Cards/GoalCardView.swift:13`
- Modify: `WorkoutApp/Features/Onboarding/Cards/FitnessLevelCardView.swift:13`
- Modify: `WorkoutApp/Features/Onboarding/Cards/DaysPerWeekCardView.swift:13`
- Modify: `WorkoutApp/Features/Onboarding/Cards/EquipmentCardView.swift:16`
- Modify: `WorkoutApp/Features/Onboarding/Cards/InjuriesCardView.swift:27`
- Modify: `WorkoutApp/Features/Onboarding/Cards/SessionLengthCardView.swift:20`

Each card currently calls `OnboardingHeroIcon(symbol: "<emoji>")`. Replace with the new `iconName:` + `gradient:` parameters.

- [ ] **Step 1: Update GoalCardView.swift**

Change line 13 from:
```swift
OnboardingHeroIcon(symbol: "🎯")
```
to:
```swift
OnboardingHeroIcon(
    iconName: "scope",
    gradient: [Color(red: 0.96, green: 0.62, blue: 0.04), Color(red: 0.92, green: 0.35, blue: 0.05)]
)
```

- [ ] **Step 2: Update FitnessLevelCardView.swift**

Change line 13 from:
```swift
OnboardingHeroIcon(symbol: "💪")
```
to:
```swift
OnboardingHeroIcon(
    iconName: "chart.xyaxis.line",
    gradient: [Color(red: 0.55, green: 0.36, blue: 0.96), Color(red: 0.43, green: 0.16, blue: 0.85)]
)
```

- [ ] **Step 3: Update DaysPerWeekCardView.swift**

Change line 13 from:
```swift
OnboardingHeroIcon(symbol: "📅")
```
to:
```swift
OnboardingHeroIcon(
    iconName: "calendar",
    gradient: [Color(red: 0.23, green: 0.51, blue: 0.96), Color(red: 0.11, green: 0.31, blue: 0.85)]
)
```

- [ ] **Step 4: Update EquipmentCardView.swift**

Change line 16 from:
```swift
OnboardingHeroIcon(symbol: "🏋️")
```
to:
```swift
OnboardingHeroIcon(
    iconName: "figure.strengthtraining.traditional",
    gradient: [Color(red: 0.06, green: 0.73, blue: 0.51), Color(red: 0.02, green: 0.47, blue: 0.34)]
)
```

- [ ] **Step 5: Update InjuriesCardView.swift**

Change line 27 from:
```swift
OnboardingHeroIcon(symbol: "🩹")
```
to:
```swift
OnboardingHeroIcon(
    iconName: "heart.text.square",
    gradient: [Color(red: 0.96, green: 0.25, blue: 0.37), Color(red: 0.75, green: 0.07, blue: 0.24)]
)
```

- [ ] **Step 6: Update SessionLengthCardView.swift**

Change line 20 from:
```swift
OnboardingHeroIcon(symbol: "\u{23F1}")
```
to:
```swift
OnboardingHeroIcon(
    iconName: "timer",
    gradient: [Color(red: 0.02, green: 0.71, blue: 0.83), Color(red: 0.05, green: 0.46, blue: 0.56)]
)
```

- [ ] **Step 7: Build to verify all onboarding changes compile**

Run: `xcodebuild build -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 8: Commit**

```bash
git add WorkoutApp/Features/Onboarding/Cards/
git commit -m "feat: replace onboarding emoji with SF Symbol gradient icons"
```

---

### Task 3: Update DifficultyRating model

**Files:**
- Modify: `WorkoutApp/Features/Models/DifficultyRating.swift`

Replace the `.emoji` computed property with `.iconName`, `.gradientColors`, and `.strokeColor` properties.

- [ ] **Step 1: Replace DifficultyRating computed properties**

Replace the entire file content:

```swift
import SwiftUI

/// Difficulty rating captured after each session (D-01, D-02).
/// Raw values match Supabase CHECK constraint and Edge Function expectations exactly.
enum DifficultyRating: String, CaseIterable, Codable {
    case tooEasy   = "too_easy"
    case justRight = "just_right"
    case tooHard   = "too_hard"

    var iconName: String {
        switch self {
        case .tooEasy:   return "face.smiling"
        case .justRight: return "face.smiling"
        case .tooHard:   return "face.dashed"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .tooEasy:   return [Color(red: 0.65, green: 0.95, blue: 0.82), Color(red: 0.43, green: 0.91, blue: 0.74)]
        case .justRight: return [Color(red: 0.99, green: 0.90, blue: 0.54), Color(red: 0.96, green: 0.62, blue: 0.04)]
        case .tooHard:   return [Color(red: 0.99, green: 0.79, blue: 0.79), Color(red: 0.97, green: 0.44, blue: 0.44)]
        }
    }

    var strokeColor: Color {
        switch self {
        case .tooEasy:   return Color(red: 0.02, green: 0.37, blue: 0.27)
        case .justRight: return Color(red: 0.47, green: 0.21, blue: 0.06)
        case .tooHard:   return Color(red: 0.50, green: 0.11, blue: 0.11)
        }
    }

    var label: String {
        switch self {
        case .tooEasy:   return "Too Easy"
        case .justRight: return "Just Right"
        case .tooHard:   return "Too Hard"
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add WorkoutApp/Features/Models/DifficultyRating.swift
git commit -m "refactor: replace DifficultyRating emoji with icon and gradient properties"
```

---

### Task 4: Update SessionSummaryView difficulty picker and trophy emoji

**Files:**
- Modify: `WorkoutApp/Features/Session/Components/SessionSummaryView.swift:82,119-137`

Two changes in this file: (1) replace the trophy emoji with an SF Symbol, (2) replace the emoji difficulty picker with gradient circle icons.

- [ ] **Step 1: Replace trophy emoji at line 82**

Change lines 81-83 from:
```swift
HStack(spacing: 8) {
    Text("\u{1F3C6}")
        .font(.title3)
    Text("New Records")
```
to:
```swift
HStack(spacing: 8) {
    Image(systemName: "trophy.fill")
        .font(.title3)
        .foregroundStyle(Theme.accent)
    Text("New Records")
```

- [ ] **Step 2: Replace emoji difficulty picker (lines 119-137)**

Change the difficulty rating section from:
```swift
HStack(spacing: 24) {
    ForEach(DifficultyRating.allCases, id: \.self) { rating in
        Button {
            selectedRating = rating
        } label: {
            VStack(spacing: 4) {
                Text(rating.emoji)
                    .font(.system(size: 44))
                    .opacity(selectedRating == nil || selectedRating == rating ? 1.0 : 0.3)
                    .scaleEffect(selectedRating == rating ? 1.15 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedRating)
                Text(rating.label)
                    .font(.caption2)
                    .foregroundStyle(selectedRating == rating ? Theme.accent : .secondary)
            }
        }
        .accessibilityLabel(rating.label)
    }
}
```
to:
```swift
HStack(spacing: 24) {
    ForEach(DifficultyRating.allCases, id: \.self) { rating in
        Button {
            selectedRating = rating
        } label: {
            VStack(spacing: 4) {
                Image(systemName: rating.iconName)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(rating.strokeColor)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: rating.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: rating.gradientColors.last?.opacity(0.3) ?? .clear, radius: 8)
                    .opacity(selectedRating == nil || selectedRating == rating ? 1.0 : 0.3)
                    .scaleEffect(selectedRating == rating ? 1.15 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedRating)
                Text(rating.label)
                    .font(.caption2)
                    .foregroundStyle(selectedRating == rating ? rating.gradientColors.last ?? Theme.accent : .secondary)
            }
        }
        .accessibilityLabel(rating.label)
    }
}
```

- [ ] **Step 3: Build to verify**

Run: `xcodebuild build -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add WorkoutApp/Features/Session/Components/SessionSummaryView.swift
git commit -m "feat: replace session summary emoji with SF Symbol icons"
```

---

### Task 5: Replace flame emoji in WeekStreakBar

**Files:**
- Modify: `WorkoutApp/Features/Main/Components/WeekStreakBar.swift:31`

Replace the inline `🔥` emoji text with an `HStack` containing an SF Symbol image and the streak text.

- [ ] **Step 1: Replace streak label at line 31**

Change lines 30-34 from:
```swift
// MARK: - Streak Label
Text("🔥 \(currentStreak) day streak")
    .font(.body)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, alignment: .center)
```
to:
```swift
// MARK: - Streak Label
HStack(spacing: 4) {
    Image(systemName: "flame.fill")
        .foregroundStyle(Theme.accent)
    Text("\(currentStreak) day streak")
        .foregroundStyle(.secondary)
}
.font(.body)
.frame(maxWidth: .infinity, alignment: .center)
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild build -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add WorkoutApp/Features/Main/Components/WeekStreakBar.swift
git commit -m "feat: replace streak flame emoji with SF Symbol"
```

---

### Task 6: Final build verification

- [ ] **Step 1: Clean build to verify everything compiles**

Run: `xcodebuild clean build -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' -quiet 2>&1 | tail -5`

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Grep for any remaining emoji**

Run: `grep -rn '[\x{1F300}-\x{1F9FF}]' WorkoutApp/ --include='*.swift'` or search for the specific emoji characters that were replaced: `🎯`, `💪`, `📅`, `🏋`, `🩹`, `😴`, `😤`, `🔥`, `🏆`

Expected: No matches in any Swift files.

- [ ] **Step 3: Verify no references to removed `.emoji` property**

Search for `\.emoji` in Swift files to ensure nothing still calls `DifficultyRating.emoji`.

Expected: No matches.
