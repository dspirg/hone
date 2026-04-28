---
phase: 12-app-store-submission
plan: "04"
subsystem: assets
tags: [app-icon, core-graphics, png, gap-closure]
dependency_graph:
  requires: ["12-02"]
  provides: ["AppIcon-1024.png asset for App Store submission"]
  affects: ["WorkoutApp/Assets.xcassets/AppIcon.appiconset/"]
tech_stack:
  added: []
  patterns: ["CoreGraphics bitmap context (RGB no-alpha)", "CoreText glyph path for gradient text", "CGImageDestination PNG export"]
key_files:
  created:
    - WorkoutApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
    - scripts/generate-app-icon.swift
  modified: []
decisions:
  - Used CTFontCreatePathForGlyph + clip + linear gradient to achieve gradient lettermark (avoids rasterizing text separately)
  - Helvetica-Bold at dynamically-scaled point size so H fills 58% of canvas regardless of CoreText metrics
  - Device RGB color space (not sRGB) for exact hex matching in CGContext
metrics:
  duration: "~1 minute"
  completed: "2026-04-28T13:57:00Z"
  tasks_completed: 1
  tasks_total: 1
  files_created: 2
  files_modified: 0
---

# Phase 12 Plan 04: AppIcon Generation Summary

**One-liner:** 1024x1024 RGB PNG app icon with bold H lettermark in amber-to-orange gradient generated via CoreGraphics + CoreText Swift script.

## What Was Built

A standalone Swift script (`scripts/generate-app-icon.swift`) that uses CoreGraphics and CoreText to programmatically generate the app icon:

1. Creates a 1024x1024 `CGContext` with `CGImageAlphaInfo.noneSkipLast` (RGB, no alpha — required by App Store).
2. Fills background with `#0a0a0a` (near-black).
3. Uses `CTFontCreateWithName("Helvetica-Bold", ...)` scaled so the H capital height occupies 58% of the canvas (~594px).
4. Extracts the H glyph path via `CTFontCreatePathForGlyph`, translates it to canvas center.
5. Clips the context to the H path and draws a `CGGradient` from amber (`#f59e0b`) at the top to orange (`#f97316`) at the bottom.
6. Exports to PNG via `CGImageDestinationCreateWithURL` with `public.png` UTI.

Output: `WorkoutApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` — 65 KB, verified 1024x1024, `hasAlpha: no`.

## Verification Results

```
sips output:
  pixelWidth: 1024
  pixelHeight: 1024
  hasAlpha: no

file command:
  PNG image data, 1024 x 1024, 8-bit/color RGB, non-interlaced
```

All three plan verification checks pass:
- `test -f ...AppIcon-1024.png` exits 0
- `sips` reports 1024x1024
- `file` shows "PNG image data, 1024 x 1024, 8-bit/color RGB"
- Contents.json continues to reference "AppIcon-1024.png" (unchanged)

## Gap Status

**Gap 1 from VERIFICATION.md: CLOSED.** AppIcon-1024.png now exists at the asset catalog path. The Contents.json reference resolves to a real file. SHIP-01 requirement satisfied.

Remaining gaps (human actions, not re-planned here):
- Gap 2: Screenshots and App Store listing metadata (SHIP-05/SHIP-06)
- Gap 3: RevenueCat production key configuration (SHIP-03/SHIP-04)

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 2751bfe | feat(12-04): generate AppIcon-1024.png with bold H lettermark gradient |

## Deviations from Plan

None — plan executed exactly as written.

## Threat Surface Scan

No new network endpoints, auth paths, or runtime code introduced. Static PNG asset and a local build script only. Matches T-12-04-01 (accept disposition, cosmetic asset).

## Self-Check: PASSED

- `WorkoutApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` — FOUND
- `scripts/generate-app-icon.swift` — FOUND
- Commit `2751bfe` — FOUND (`git log --oneline | grep 2751bfe` confirms)
