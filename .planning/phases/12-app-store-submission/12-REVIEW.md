---
phase: 12-app-store-submission
reviewed: 2026-04-28T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - Config/Prod.xcconfig
  - WorkoutApp.xcodeproj/project.pbxproj
  - WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json
  - WorkoutApp/PrivacyInfo.xcprivacy
  - docs/privacy-policy.html
findings:
  critical: 4
  warning: 2
  info: 3
  total: 9
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-04-28
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed five files scoped to App Store submission readiness: the production xcconfig, Xcode project file, app icon asset catalog, privacy manifest, and privacy policy HTML. The files span configuration, build settings, and submission metadata.

Four critical issues were found: the app icon PNG is missing entirely (archive will fail), the production RevenueCat API key is an unfilled placeholder (runtime crash on launch), a live Supabase JWT is committed to version control in both xcconfig files, and the `PrivacyInfo.xcprivacy` privacy manifest omits fitness/health data types that the app clearly collects. Two warnings cover a duplicate Core Data model file in the project (potential runtime data corruption) and a dangling `StoreKitConfigTests.swift` reference with mismatched object IDs. Three informational items round out the review.

---

## Critical Issues

### CR-01: App Icon PNG File Missing — Archive Will Fail

**File:** `WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json:4`
**Issue:** `Contents.json` declares `"filename": "AppIcon-1024.png"` but the file does not exist in the `AppIcon.appiconset/` directory. Running an archive build will fail with an asset catalog compile error: "The app icon set … does not have a 1024x1024 app icon." App Store Connect upload requires a 1024×1024 PNG with no alpha channel, no rounded corners.
**Fix:** Add a 1024×1024 PNG named `AppIcon-1024.png` to `WorkoutApp/Assets.xcassets/AppIcon.appiconset/`. Requirements: PNG format, no alpha channel (flatten if needed), no rounded corners (Apple applies them), sRGB or Display P3 color space.

### CR-02: Production RevenueCat API Key Is an Unfilled Placeholder

**File:** `Config/Prod.xcconfig:6`
**Issue:** `REVENUECAT_API_KEY = appl_REPLACE_WITH_PROD_RC_KEY` is the literal placeholder string. The Release build configuration uses `Prod.xcconfig` as its base. When `RevenueCat.configure(withAPIKey:)` is called with this placeholder string, RevenueCat will reject it and the subscription system will not function — users will be unable to purchase or restore subscriptions. The app will likely fail App Store review in the subscription flow.
**Fix:** Replace with the real production iOS API key from RevenueCat Dashboard > Project > Apps > iOS > Public API Key (format: `appl_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`). This key should not be treated as a secret (it is public), so it is safe to commit once obtained.

### CR-03: Live Supabase JWT Committed to Version Control in Both xcconfig Files

**File:** `Config/Prod.xcconfig:5` and `Config/Dev.xcconfig:5`
**Issue:** The `SUPABASE_ANON_KEY` value is a full JWT (`eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9…`) committed in both xcconfig files, and both files point to the same production Supabase project (`seuzjlqfetbefzdplulz.supabase.co`). The Dev config comment claims it contains "local dev keys (standard Supabase local dev defaults)" but it contains the same production project URL and key as Prod. The anon key itself is a semi-public credential by design (Row Level Security is the protection layer), but committing it means anyone with repo access has a permanent copy, and rotating it requires a repo history rewrite. More critically, Dev and Prod point to the same Supabase project — development work runs against production data.
**Fix (two-part):**
1. Add a root `.gitignore` to the repository and add `Config/Prod.xcconfig` to it (or move secrets to environment variables / CI secrets). At minimum add a root-level `.gitignore`:
```
# Secrets
Config/Prod.xcconfig
SubscriptionKey_3QM8JG26CT.p8
```
2. Provision a separate Supabase project for development, or use `supabase start` with the Supabase CLI to run a local instance, and update `Dev.xcconfig` to point to `http://127.0.0.1:54321` (local) or a staging project.

### CR-04: Privacy Manifest Missing Fitness and Health Data Types

**File:** `WorkoutApp/PrivacyInfo.xcprivacy:9-35`
**Issue:** `NSPrivacyCollectedDataTypes` only declares `NSPrivacyCollectedDataTypePurchaseHistory` and `NSPrivacyCollectedDataTypeEmailAddress`. The privacy policy (`docs/privacy-policy.html`) explicitly states the app collects: workout history, fitness preferences (fitness level, training goals, equipment, injury notes), and exercise performance data. Apple's App Store privacy nutrition label requires all collected data types to be declared. The missing declarations will likely trigger App Store review rejection under guideline 5.1.1 (Data Collection and Storage). Missing types include at minimum:
- `NSPrivacyCollectedDataTypeHealth` (workout history, exercise performance, difficulty ratings)
- `NSPrivacyCollectedDataTypeOtherUserContent` or `NSPrivacyCollectedDataTypePerformance` (fitness preferences, injury notes)

**Fix:** Add the missing data type entries to `PrivacyInfo.xcprivacy`. Example for workout/health data:
```xml
<dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeHealth</string>
    <key>NSPrivacyCollectedDataTypeLinked</key>
    <true/>
    <key>NSPrivacyCollectedDataTypeTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
    </array>
</dict>
```
Also add `NSPrivacyCollectedDataTypeFitnessData` if Apple's current taxonomy includes it (verify against the current App Store privacy types list at developer.apple.com/app-store/app-privacy-details/).

---

## Warnings

### WR-01: Duplicate Core Data Model File References in Project

**File:** `WorkoutApp.xcodeproj/project.pbxproj:37,63` and `198,224`
**Issue:** Two separate `PBXFileReference` entries exist for `WorkoutApp.xcdatamodeld`:
- `B003A00000000005` at path `WorkoutApp.xcdatamodeld` (line 198)
- `B002000030000003` at path `WorkoutApp.xcdatamodeld` (line 224)

Both are added to the Sources build phase:
- `B003A00100000005` (line 37) referencing `B003A00000000005`
- `B002000100000004` (line 63) referencing `B002000030000003`

Compiling the same `.xcdatamodeld` twice causes a warning at best and can cause the Core Data model version hash to be computed incorrectly, leading to a migration failure crash at launch (`NSPersistentStore: could not initialize`). The `PersistenceController` will attempt to load a model that may not resolve deterministically.
**Fix:** Open Xcode and delete the duplicate `.xcdatamodeld` reference from the project navigator (keep only one). Verify in the `.pbxproj` that only a single `PBXFileReference` and single `PBXBuildFile` entry reference `WorkoutApp.xcdatamodeld`. After cleanup, do a clean build and verify Core Data loads correctly.

### WR-02: StoreKitConfigTests.swift Has Mismatched Object IDs — File May Not Compile

**File:** `WorkoutApp.xcodeproj/project.pbxproj:434,1067`
**Issue:** `StoreKitConfigTests.swift` appears in the PBXGroup with ID `E7F1A2B3C4D5E6F708192021` (line 434) and in PBXSourcesBuildPhase with ID `E7F1A2B3C4D5E6F708192022` (line 1067). These are different object IDs. Additionally, no `PBXFileReference` entry exists for either ID in the file reference section (lines 164–303). The file references a nonexistent file reference object, which means Xcode will show a broken red reference in the navigator and the file will not be compiled into the test target.
**Fix:** Remove the orphaned entries from both the PBXGroup and PBXSourcesBuildPhase sections, then re-add the file through Xcode's "Add Files" dialog to generate a consistent set of object IDs. Alternatively, if the file does not exist on disk yet, remove both references until the file is created.

---

## Info

### IN-01: SwiftUI Previews Enabled in Release Build Configuration

**File:** `WorkoutApp.xcodeproj/project.pbxproj:1265`
**Issue:** `ENABLE_PREVIEWS = YES` is present in the Release target build configuration (`B001000050000040`). SwiftUI preview infrastructure adds overhead and should be disabled for production archive builds.
**Fix:** Set `ENABLE_PREVIEWS = NO` in the Release target build configuration in Xcode (Target > Build Settings > Enable Previews > Release = No).

### IN-02: Privacy Policy Effective Date Lacks a Specific Day

**File:** `docs/privacy-policy.html:145,267`
**Issue:** The effective date is stated as "April 2026" with no specific calendar day. App Store Connect's privacy policy URL field does not validate date format, but legal best practice and some data protection regulations (GDPR) require a specific date for the policy version. The footer also repeats "Effective April 2026".
**Fix:** Update to a specific date, e.g., `April 28, 2026` in both the `<p class="effective-date">` tag (line 145) and the footer `<p>` (line 267).

### IN-03: Dev and Prod xcconfig Files Are Identical in Substance

**File:** `Config/Dev.xcconfig:1-8` and `Config/Prod.xcconfig:1-6`
**Issue:** Both files point to the same Supabase URL and use the same anon key. The only difference is the RevenueCat key (Dev has a sandbox key, Prod has a placeholder). This means Debug builds run against the production Supabase database, which risks polluting production data during development and testing.
**Fix:** Addressed by CR-03 fix item 2 above (provision a separate Supabase project or use a local instance for Dev). This is listed as Info because it is a consequence of the Critical issue rather than an independent problem.

---

_Reviewed: 2026-04-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
