---
phase: 12-app-store-submission
plan: "03"
subsystem: app-store-connect
tags: [app-store-connect, subscriptions, screenshots, listing-metadata, submission]

dependency_graph:
  requires:
    - phase: 12-02
      provides: [Archive build verified, PrivacyInfo.xcprivacy bundled, Prod.xcconfig with Supabase keys]
  provides:
    - App Store Connect app record created (com.danspirgen.hone)
    - Subscription products registered (com.workoutapp.pro.monthly, com.workoutapp.pro.annual)
  affects: []

tech-stack:
  added: []
  patterns: []

self-check: PARTIAL

key-files:
  created: []
  modified: []

decisions:
  - rationale: "App record and subscription products created first to unblock build upload and screenshot workflow"
    alternatives_considered: ["Do everything in one session"]

deviations: []
---

## Summary

Plan 12-03 is partially complete. The App Store Connect foundation is set up but the submission workflow is not yet finished.

### Completed
- **Task 1:** App Store Connect app record created with bundle ID `com.danspirgen.hone`, name "Hone - AI Workout Coach"
- **Task 1:** Subscription products registered in App Store Connect:
  - `com.workoutapp.pro.monthly` — $12.99/month, 14-day free trial
  - `com.workoutapp.pro.annual` — $79.99/year, 14-day free trial
- **Task 1:** RevenueCat products configured and linked

### Remaining (human actions)
- **Build upload:** Archive the app in Xcode and upload via Organizer → App Store Connect
- **Screenshots:** Capture 4 screenshots at both 6.9" (1320x2868) and 6.1" (1179x2556):
  1. Home Screen — "Your workout, ready to go"
  2. AI Coach Chat — "Meet Hone, your AI coach"
  3. Active Session — "Guided sessions, every rep"
  4. Session Summary — "Track your progress"
- **Listing metadata:** Fill description, subtitle, keywords, category, privacy policy URL in App Store Connect
- **Submit for review** with both subscription products included

### Pre-submission checklist
- [ ] Fill RevenueCat production key in `Config/Prod.xcconfig` (currently placeholder)
- [ ] Commit `AppIcon-1024.png` to repo
- [ ] Archive and upload build
- [ ] Capture and upload 8 screenshots (4 per size)
- [ ] Fill listing metadata (description, keywords in plan file)
- [ ] Host privacy policy HTML on GitHub Pages
- [ ] Submit for review with IAPs attached

## Self-Check: PARTIAL

Task 1 completed (app record + subscriptions). Task 2 partially complete — build upload, screenshots, metadata, and submission remain as human actions.
