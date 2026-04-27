---
phase: 12-app-store-submission
plan: "01"
subsystem: app-store-compliance
tags: [privacy-manifest, xcprivacy, prod-config, privacy-policy, app-icon]
dependency_graph:
  requires: []
  provides: [WorkoutApp/PrivacyInfo.xcprivacy, Config/Prod.xcconfig, docs/privacy-policy.html, WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json]
  affects: [WorkoutApp.xcodeproj/project.pbxproj]
tech_stack:
  added: []
  patterns: [Apple privacy manifest XML plist, xcconfig URL escaping with $(), GitHub Pages static HTML]
key_files:
  created:
    - WorkoutApp/PrivacyInfo.xcprivacy
    - docs/privacy-policy.html
  modified:
    - Config/Prod.xcconfig
    - WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json
    - WorkoutApp.xcodeproj/project.pbxproj
decisions:
  - "Prod.xcconfig uses same Supabase URL and anon key as Dev.xcconfig — single hosted Supabase project, no staging/production split needed"
  - "RevenueCat production key retained as appl_REPLACE_WITH_PROD_RC_KEY placeholder — requires manual fetch from RevenueCat Dashboard in Plan 03"
  - "PrivacyInfo.xcprivacy declares UserDefaults CA92.1 (RevenueCat SDK caching) + PurchaseHistory + EmailAddress collected data types"
  - "PrivacyInfo.xcprivacy uses lastKnownFileType = text.xml in project.pbxproj (correct type for .xcprivacy files)"
metrics:
  duration: "18 minutes"
  completed: "2026-04-27"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 3
---

# Phase 12 Plan 01: App Store Compliance Foundation Summary

Apple privacy manifest, production config, app icon slot, and privacy policy — all automatable pre-submission files created and wired into the Xcode project.

## What Was Built

Four files that form the code/config foundation for App Store submission:

1. **WorkoutApp/PrivacyInfo.xcprivacy** — Apple's required privacy manifest, declaring `NSPrivacyTracking=false`, no tracking domains, UserDefaults access with reason CA92.1, PurchaseHistory (RevenueCat) and EmailAddress (Supabase Auth) as collected data types. Added to Copy Bundle Resources build phase in project.pbxproj.

2. **Config/Prod.xcconfig** — Filled with real Supabase URL and anon key (same as Dev.xcconfig since there is a single hosted Supabase project). RevenueCat production key stays as placeholder for Plan 03 human action.

3. **WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json** — Added `"filename": "AppIcon-1024.png"` to the existing 1024x1024 universal iOS entry. Slot is ready; the actual PNG is a design asset created by the user.

4. **docs/privacy-policy.html** — Complete standalone privacy policy page styled with Hone brand colors (dark #0a0a0a, amber #f59e0b headings). Covers: email collection, workout history, AI processing via OpenAI, third-party services (Supabase, RevenueCat, Mux, OpenAI), data security, user rights, children's privacy, and contact. Ready for GitHub Pages hosting as the App Store Connect privacy policy URL.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | a7ffb46 | chore(12-01): add PrivacyInfo.xcprivacy and fill Prod.xcconfig |
| Task 2 | 723f425 | feat(12-01): update AppIcon Contents.json and create privacy policy HTML |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

| Stub | File | Reason |
|------|------|--------|
| REVENUECAT_API_KEY = appl_REPLACE_WITH_PROD_RC_KEY | Config/Prod.xcconfig | Intentional: production RevenueCat public SDK key requires human fetch from RevenueCat Dashboard. Plan 03 (human action) resolves this. |
| AppIcon-1024.png (PNG not yet present) | WorkoutApp/Assets.xcassets/AppIcon.appiconset/ | Intentional: design asset created by user. Contents.json slot is ready. Plan 02 covers icon PNG creation. |

## Threat Flags

None — no new trust boundaries introduced. Supabase anon key in Prod.xcconfig is a client-safe public key; RLS enforces server-side data isolation (per T-12-01 accepted disposition in plan threat model).

## Self-Check: PASSED

All created files verified present on disk. Both task commits verified in git log.
