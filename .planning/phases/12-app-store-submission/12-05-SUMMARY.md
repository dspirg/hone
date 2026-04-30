---
phase: 12-app-store-submission
plan: 05
status: complete
started: "2026-04-30T06:00:00Z"
completed: "2026-04-30T06:30:00Z"
---

## Summary

Created App Store listing metadata reference document and completed pre-submission setup: RevenueCat production key configured, privacy policy hosted on GitHub Pages.

## What Was Built

- `docs/app-store-listing.md` — Complete App Store Connect listing reference with app name, subtitle, description, keywords, category, screenshot specs, and submission checklist
- `Config/Prod.xcconfig` — RevenueCat production API key filled (`appl_efPqktxpbrfQbXOhuUnuoGopQYa`)
- Privacy policy live at `https://dspirg.github.io/hone/privacy-policy.html`
- Repository pushed to GitHub (`dspirg/hone`) with GitHub Pages enabled

## Key Files

### Created
- `docs/app-store-listing.md` — Listing metadata reference for copy-paste into App Store Connect

### Modified
- `Config/Prod.xcconfig` — Production RevenueCat API key set

## Human Checkpoint Items (Remaining)

The following items require manual action in Xcode and App Store Connect:

- [ ] Archive build in Xcode (Product > Archive)
- [ ] Upload build to App Store Connect via Xcode Organizer
- [ ] Capture 8 screenshots (4 per device size: 6.9" and 6.1")
- [ ] Fill all listing fields in App Store Connect (copy from docs/app-store-listing.md)
- [ ] Attach both subscription products to review submission
- [ ] Submit for App Store review

## Self-Check: PASSED

- [x] docs/app-store-listing.md exists with all listing fields
- [x] Config/Prod.xcconfig has real RevenueCat key (not placeholder)
- [x] Privacy policy hosted and accessible
- [x] Listing doc contains all required content (title, subtitle, description, keywords, screenshot specs, checklist)

## Deviations

- Archive build verification via command line failed due to iOS 26.2 SDK requiring proper signing (not ad-hoc). This is expected — actual archive must be done through Xcode GUI with developer certificate.
