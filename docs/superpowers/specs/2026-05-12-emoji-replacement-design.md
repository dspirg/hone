# Replace Emoji Icons with SF Symbols + Styled Containers

**Date:** 2026-05-12
**Status:** Approved

## Problem

The app uses 9 emoji characters across onboarding, difficulty rating, and inline text. They look cheap and inconsistent with the 23 SF Symbols already used elsewhere in the app.

## Approach

Replace all emoji with SF Symbols inside gradient-colored containers (approach B). Zero new dependencies — uses Apple's built-in SF Symbols with custom gradient backgrounds for visual personality.

## 1. Onboarding Hero Icons

Refactor `OnboardingHeroIcon` to accept an SF Symbol name and gradient color pair instead of an emoji string. Container changes from `Circle` to `RoundedRectangle(cornerRadius: 18)`.

| Card | Current Emoji | SF Symbol | Gradient (135deg) |
|------|--------------|-----------|-------------------|
| Goal | `🎯` | `scope` | `#F59E0B` → `#EA580C` (Amber → Burnt Orange) |
| Fitness Level | `💪` | `chart.xyaxis.line` | `#8B5CF6` → `#6D28D9` (Violet → Deep Purple) |
| Days/Week | `📅` | `calendar` | `#3B82F6` → `#1D4ED8` (Blue → Deep Blue) |
| Equipment | `🏋️` | `figure.strengthtraining.traditional` | `#10B981` → `#047857` (Emerald → Deep Green) |
| Injuries | `🩹` | `heart.text.square` | `#F43F5E` → `#BE123C` (Rose → Deep Rose) |
| Session Length | `⏱️` | `timer` | `#06B6D4` → `#0E7490` (Cyan → Deep Cyan) |

**Component spec:**
- Container: 72x72pt, `RoundedRectangle(cornerRadius: 18)`
- Background: `LinearGradient(colors:startPoint:.topLeading,endPoint:.bottomTrailing)`
- Icon: `Image(systemName:)` at 28pt, white, `.font(.system(size: 28, weight: .medium))`
- Shadow: matching gradient start color at 0.35 opacity, radius 12
- Animation: existing spring animation on appear (unchanged)

## 2. Difficulty Rating Picker

Replace emoji faces with SF Symbol face icons inside sentiment-colored circles. The `DifficultyRating` model's `.emoji` computed property is replaced with `.iconName`, `.gradientColors`, and `.strokeColor`.

| Rating | Current Emoji | SF Symbol | Circle Gradient (135deg) | Stroke Color |
|--------|--------------|-----------|-------------------------|--------------|
| Too Easy | `😴` | `face.smiling` | `#A7F3D0` → `#6EE7B7` (Mint) | `#065F46` (Dark Green) |
| Just Right | `💪` | `face.smiling` | `#FDE68A` → `#F59E0B` (Amber) | `#78350F` (Dark Amber) |
| Too Hard | `😤` | `face.dashed` | `#FECACA` → `#F87171` (Red) | `#7F1D1D` (Dark Red) |

**Component spec:**
- Container: 56x56pt, `Circle()`
- Background: `LinearGradient` with sentiment colors
- Icon: `Image(systemName:)` at 28pt, stroke color matching gradient
- Shadow: gradient end color at 0.3 opacity, radius 8
- Selected state: existing scale + spring animation (unchanged)
- Label color changes to match gradient end color when selected (replaces `Theme.accent`)

## 3. Inline Text Accents

Replace inline emoji text with `Image(systemName:)` tinted with `Theme.accent`. No containers.

| Location | Current | Replacement |
|----------|---------|-------------|
| `WeekStreakBar.swift` line 31 | `"🔥 \(currentStreak) day streak"` | `Image(systemName: "flame.fill")` + `Text(...)`, both in an `HStack` |
| `SessionSummaryView.swift` line 82 | `Text("\u{1F3C6}")` | `Image(systemName: "trophy.fill")` |

Both icons use `.foregroundStyle(Theme.accent)` and match the surrounding text size.

## Files Changed

1. **`OnboardingHeroIcon.swift`** — refactor interface from `symbol: String` (emoji) to `iconName: String` + `gradient: [Color]`
2. **`GoalCardView.swift`** — pass `iconName: "scope"` + gradient colors
3. **`FitnessLevelCardView.swift`** — pass `iconName: "chart.xyaxis.line"` + gradient colors
4. **`DaysPerWeekCardView.swift`** — pass `iconName: "calendar"` + gradient colors
5. **`EquipmentCardView.swift`** — pass `iconName: "figure.strengthtraining.traditional"` + gradient colors
6. **`InjuriesCardView.swift`** — pass `iconName: "heart.text.square"` + gradient colors
7. **`SessionLengthCardView.swift`** — pass `iconName: "timer"` + gradient colors
8. **`DifficultyRating.swift`** — replace `.emoji` with `.iconName`, `.gradientColors`, `.strokeColor`
9. **`SessionSummaryView.swift`** — update difficulty picker rendering + replace trophy emoji
10. **`WeekStreakBar.swift`** — replace flame emoji with SF Symbol

## Out of Scope

- No changes to the 23 existing SF Symbols already in use
- No new asset catalog entries (all colors defined in code as `Color(red:green:blue:)`)
- No changes to animation behavior
- No accessibility label changes needed (text labels already exist alongside all emoji)
