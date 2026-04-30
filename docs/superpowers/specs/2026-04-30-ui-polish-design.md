# UI Polish for App Store Screenshots

**Date:** 2026-04-30
**Goal:** Make the app look premium and screenshot-ready before App Store submission.
**Scope:** 6 visual improvements across Home, Session, Coach, Summary, Onboarding, and Tab Bar.

---

## 1. Home Screen: Workout Card Visual Upgrade

### Changes
- **Greeting name in amber:** "Hey **Dan**" — the name portion renders in `Theme.accent` instead of primary white.
- **Workout card gradient border:** A 1px wrapper view with `LinearGradient` from `Theme.accent.opacity(0.3)` to `Theme.accent.opacity(0.05)` at 135 degrees. Inner card remains `Theme.surface`.
- **Day badge pill:** "Day 1" becomes a capsule with `Theme.accent` background and black text instead of plain accent text.
- **CTA glow:** "Start Workout" button uses `LinearGradient` fill (amber → #f97316) and adds `.shadow(color: Theme.accent.opacity(0.3), radius: 10, y: 4)`.
- **Today's streak tile glow:** The today tile (amber border) adds `.shadow(color: Theme.accent.opacity(0.2), radius: 6)`.
- **Exercise row thumbnails:** Replace gray placeholder squares with `AsyncImage` loading from `exercise.thumbnailURL` (already available on `ExerciseModel`). Fall back to first-letter initial on failure.

### Files Modified
- `WorkoutApp/Features/Main/Tabs/HomeView.swift` — greeting section, workoutCard, streakCard
- `WorkoutApp/Features/Main/Components/HomeExerciseRowView.swift` — thumbnail AsyncImage

---

## 2. Session: Progress Bar & Set Completion Polish

### Changes
- **Active set highlight:** The current set row gets a subtle amber border (`Theme.accent.opacity(0.3)`) and tinted background (`Theme.accent.opacity(0.03)`), with the set number circle showing an amber border instead of fill.
- **Status labels:** Replace silent state changes with text: "Done" in `Theme.successGreen`, "Current" in `Theme.accent`, "Upcoming" dimmed.
- **Completed set glow:** Completed set number circle and checkmark get `.shadow(color: Theme.accent.opacity(0.4), radius: 6)`.
- **Progress bar glow:** Completed segments get `.shadow(color: Theme.accent.opacity(0.4), radius: 3)`. Current segment shows partial fill via `GeometryReader` based on completed sets / total sets for that exercise.
- **CTA gradient + glow:** Same gradient button treatment as Home ("Complete Set" / "Next Exercise" / "Finish Session").
- **Haptic feedback:** `UIImpactFeedbackGenerator(style: .medium).impactOccurred()` on set checkmark tap.
- **Spring animation:** `.scaleEffect` with `.spring(response: 0.3, dampingFraction: 0.5)` on checkmark tap, animating from 1.0 → 1.15 → 1.0.

### Files Modified
- `WorkoutApp/Features/Session/Components/ExerciseCardView.swift` — set rows, CTA button
- `WorkoutApp/Features/Session/SessionView.swift` — progress bar segments

---

## 3. Coach Chat: Richer Message Bubbles

### Changes
- **Markdown rendering in coach bubbles:** Parse AI responses for basic markdown: `**bold**` → bold white text, `\n1. ` / `\n2. ` → amber-numbered formatted lists, `\n- ` → styled bullet points. Implement as a simple regex-based `AttributedString` builder (15-20 lines, not a full markdown library). Only these three patterns — no headers, code blocks, or links.
- **Exercise mini-cards:** When the AI mentions an exercise name that matches the database, render an inline card with thumbnail placeholder, exercise name, muscle group, and "View ›" link. Tap navigates to `ExerciseDetailView`.
- **User bubble tint:** Change user message background from solid accent to `Theme.accent.opacity(0.15)` with white text for less visual weight.
- **Bubble shape:** Coach bubbles use `.leading` rounded corners (small top-left radius). User bubbles use `.trailing` rounded corners (small bottom-right radius).
- **Online status:** Add "Online" label in `Theme.successGreen` below "Hone" in the header.
- **Send button:** Amber circle with arrow icon instead of text button.

### Files Modified
- `WorkoutApp/Features/Main/Tabs/CoachView.swift` — bubble styling, header
- `WorkoutApp/Features/Coach/Components/ChatBubbleView.swift` — markdown parsing, exercise card detection
- New: `WorkoutApp/Features/Coach/Components/ExerciseMiniCardView.swift` — inline exercise card

---

## 4. Session Summary: Celebration Moment

### Changes
- **Confetti burst:** On appear, if the session has PRs, trigger a confetti animation. Use a custom `ConfettiView` (Canvas API or pre-built particles) with amber, green, and blue particles. Duration: ~2 seconds, then fade out.
- **Dynamic heading:** Replace static "Great work." with randomized text from: "Crushed it!", "Beast mode!", "Nailed it!", "Strong session!", "Great work!". Append a contextual emoji.
- **Glowing checkmark:** Increase from 36pt to 56pt, add gradient fill (amber → orange) and `.shadow(color: Theme.accent.opacity(0.4), radius: 15)`.
- **Animated stat counters:** Numbers count up from 0 using a `withAnimation(.easeOut(duration: 0.8))` on appear. Each stat starts with a slight stagger (0.1s delay between each).
- **PR section upgrade:** Wrap in an amber-bordered card with gradient background (`Theme.accent.opacity(0.1)` to `Theme.accent.opacity(0.03)`). Add trophy icon. Show old → new rep comparison per PR.
- **Haptic:** `UINotificationFeedbackGenerator().notificationOccurred(.success)` on appear.

### Files Modified
- `WorkoutApp/Features/Session/Components/SessionSummaryView.swift` — heading, stats, PR section, checkmark
- New: `WorkoutApp/Features/Session/Components/ConfettiView.swift` — particle animation

---

## 5. Onboarding: Visual Delight

### Changes
- **Hero icon circles:** Each onboarding card gets a 72pt circle with `LinearGradient` background (`Theme.accent.opacity(0.15)` to `Theme.accent.opacity(0.05)`) containing a large SF Symbol or emoji. Icons: Goal → target, Level → flexed bicep, Days → calendar, Equipment → dumbbell, Injuries → bandage.
- **Icon animation:** On card appear, the icon circle scales from 0.8 → 1.0 with `.spring(response: 0.5, dampingFraction: 0.7)` and a subtle vertical bounce.
- **Selected option styling:** Selected chips get amber border (`Theme.accent.opacity(0.3)`), amber text, and a checkmark prefix. Unselected chips use `Theme.borderSubtle`.
- **Warmer copy:** Update subtitles to be more personal: "This shapes your entire program", "We'll match your starting point", "Pick what fits your schedule", "Select all that apply", "We'll work around them".
- **Circle glow:** Hero icon circles get `.shadow(color: Theme.accent.opacity(0.1), radius: 12)`.

### Files Modified
- `WorkoutApp/Features/Onboarding/Cards/GoalCardView.swift`
- `WorkoutApp/Features/Onboarding/Cards/FitnessLevelCardView.swift`
- `WorkoutApp/Features/Onboarding/Cards/DaysPerWeekCardView.swift`
- `WorkoutApp/Features/Onboarding/Cards/EquipmentCardView.swift`
- `WorkoutApp/Features/Onboarding/Cards/InjuriesCardView.swift`

---

## 6. Tab Bar: Branded Styling

### Changes
- **Active indicator bar:** A 20×3pt amber capsule positioned above the active tab icon using a custom `TabBarAppearance` or overlay. Includes `.shadow(color: Theme.accent.opacity(0.4), radius: 4)`.
- **Blur background:** Set tab bar background to `UIColor(white: 0.086, alpha: 0.85)` with `UIBlurEffect(style: .dark)` via `UITabBarAppearance`.
- **Amber top border:** Replace default separator with a faint amber-tinted line (`Theme.accent.opacity(0.1)`).
- **Inactive icon dimming:** Unselected tab items use `#666666` instead of default `#888888` for stronger active/inactive contrast.
- **Active label weight:** Selected tab label uses semibold weight.

### Files Modified
- `WorkoutApp/Features/Main/MainTabView.swift` — tab bar appearance configuration

---

## Design Principles

- All glow/shadow effects use `Theme.accent` with low opacity (0.1–0.4) to stay subtle.
- Gradient buttons use amber (#f59e0b) → orange (#f97316) consistently across all CTAs.
- Animations are spring-based with short durations (0.3–0.5s) — never blocking.
- Haptic feedback is used sparingly: set completion and session summary only.
- No new colors introduced — all from existing `Theme` palette.
- No new dependencies — confetti uses SwiftUI Canvas, markdown uses AttributedString.
