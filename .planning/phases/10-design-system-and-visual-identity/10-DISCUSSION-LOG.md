# Phase 10: Design System and Visual Identity - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-27
**Phase:** 10-design-system-and-visual-identity
**Areas discussed:** Color system approach, Hone coach identity, Video thumbnail + fullscreen, Dark mode migration strategy

---

## Color System Approach

| Option | Description | Selected |
|--------|-------------|----------|
| Centralized Theme.swift | Create a Theme struct with static color properties — single source of truth | |
| Asset catalog only | Keep colors in xcassets, update AccentColor to amber, add new sets | |
| You decide | Let Claude pick based on codebase patterns and maintainability | ✓ |

**User's choice:** You decide
**Notes:** Claude has discretion on architecture approach

---

| Option | Description | Selected |
|--------|-------------|----------|
| Amber-only palette | Amber at various opacities, system red/green for success/error | |
| Amber + warm neutrals | Amber primary, warm gray surfaces, green success, soft red errors | |
| You decide | Let Claude pick a palette that works with dark mode and amber | ✓ |

**User's choice:** You decide
**Notes:** Claude has discretion on secondary colors

---

| Option | Description | Selected |
|--------|-------------|----------|
| Full sweep | Update all 41 views to use the new color system | ✓ |
| High-traffic screens only | Update main screens, leave auth/onboarding/paywall for later | |
| Theme file + gradual | Create theme, only touch views as modified in Phases 10-11 | |

**User's choice:** Full sweep
**Notes:** This is a design system phase — do it once, do it right

---

| Option | Description | Selected |
|--------|-------------|----------|
| Colors + typography | Define font scale in Theme file too | |
| Colors only | Phase 10 focuses on colors, thumbnails, Hone branding | ✓ |
| You decide | Let Claude determine scope | |

**User's choice:** Colors only
**Notes:** Typography standards emerge during Phase 11 screen redesigns

---

## Hone Coach Identity

| Option | Description | Selected |
|--------|-------------|----------|
| Warm gradient circle | Abstract gradient blob (amber-to-orange), no face/character | ✓ |
| Stylized character | Simple illustrated face/figure with warm colors | |
| Monogram 'H' | Letter 'H' in a warm gradient circle | |

**User's choice:** Warm gradient circle
**Notes:** Modern, clean, works at any size

---

| Option | Description | Selected |
|--------|-------------|----------|
| Chat-only branding | Hone name + avatar only in Coach chat tab | |
| Chat + system messages | Hone in chat plus adaptation summaries, plan loading, notifications | |
| Full brand presence | Hone everywhere — chat, adaptations, plan loading, notifications, home screen | ✓ |

**User's choice:** Full brand presence
**Notes:** Maximum personality across the entire experience

---

| Option | Description | Selected |
|--------|-------------|----------|
| Warm & encouraging | Supportive friend, casual but not silly | |
| Confident & direct | Expert coach, minimal fluff | |
| You decide | Let Claude pick tone fitting dark/amber premium aesthetic | ✓ |

**User's choice:** You decide
**Notes:** Claude picks personality tone

---

| Option | Description | Selected |
|--------|-------------|----------|
| Distinct styling | Hone bubbles with amber tint/gradient border, user bubbles solid dark | ✓ |
| Minimal difference | Same bubble shape, just alignment + avatar differentiator | |
| You decide | Let Claude determine approach | |

**User's choice:** Distinct styling
**Notes:** Clear visual separation between Hone and user messages

---

## Video Thumbnail + Fullscreen

| Option | Description | Selected |
|--------|-------------|----------|
| Mux thumbnail URL | Use Mux's built-in thumbnail API, zero local processing | ✓ |
| Server-generated + cached | Generate server-side, store in Supabase Storage | |
| Local AVAssetImageGenerator | Extract first frame on-device | |

**User's choice:** Mux thumbnail URL
**Notes:** Exercises already have muxPlaybackId

---

| Option | Description | Selected |
|--------|-------------|----------|
| Sheet overlay + AVPlayer | Full-screen sheet with native AVPlayerViewController | |
| Custom overlay | Custom dark overlay with exercise info below video | |
| You decide | Let Claude pick based on existing codebase patterns | ✓ |

**User's choice:** You decide
**Notes:** Claude picks fullscreen overlay approach

---

| Option | Description | Selected |
|--------|-------------|----------|
| Exercise list + session view | Thumbnails in library rows and session exercise cards | |
| Everywhere exercises show | Library, session, plan preview, coach chat — full consistency | ✓ |
| Exercise list only | Keep thumbnails in exercise library only | |

**User's choice:** Everywhere exercises show
**Notes:** Any mention of an exercise gets its thumbnail

---

## Dark Mode Migration

| Option | Description | Selected |
|--------|-------------|----------|
| .preferredColorScheme(.dark) | Set on root view, forces every screen dark | ✓ |
| Info.plist UIUserInterfaceStyle | System-level lock, cannot toggle at runtime | |
| Both (belt + suspenders) | Info.plist + SwiftUI modifier | |

**User's choice:** .preferredColorScheme(.dark)
**Notes:** One line on root view, asset catalog dark variants activate automatically

---

| Option | Description | Selected |
|--------|-------------|----------|
| Keep both variants | Leave light+dark in asset catalog for future flexibility | ✓ |
| Dark-only (strip light) | Remove light variants, commit to dark-only | |
| You decide | Let Claude pick based on requirements constraint | |

**User's choice:** Keep both variants
**Notes:** Infrastructure ready for future light mode toggle

---

| Option | Description | Selected |
|--------|-------------|----------|
| Trust the full sweep | All views updated including auth/onboarding/paywall | ✓ |
| Flag auth + onboarding | Extra attention for light-themed screens | |
| You decide | Let Claude identify screens needing special attention | |

**User's choice:** Trust the full sweep
**Notes:** No special-casing — every screen gets the treatment

---

## Claude's Discretion

- Theme architecture: centralized Theme.swift vs asset-catalog-only (D-01)
- Secondary color palette beyond amber (D-02)
- Hone's personality tone (D-07)
- Fullscreen video overlay implementation (D-11)
- Error/empty state styling for missing thumbnails
- Transition animations for fullscreen video overlay

## Deferred Ideas

None — discussion stayed within phase scope.
