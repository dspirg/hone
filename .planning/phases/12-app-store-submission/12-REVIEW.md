---
phase: 12-app-store-submission
reviewed: 2026-04-28T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - Config/Prod.xcconfig
  - docs/privacy-policy.html
  - scripts/generate-app-icon.swift
  - WorkoutApp.xcodeproj/project.pbxproj
  - WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json
  - WorkoutApp/PrivacyInfo.xcprivacy
findings:
  critical: 3
  warning: 4
  info: 3
  total: 10
status: issues_found
---

# Phase 12: Code Review Report

**Reviewed:** 2026-04-28
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Six files covering App Store submission readiness were reviewed: the production xcconfig, privacy policy HTML, app icon generation script, Xcode project file, AppIcon asset catalog descriptor, and the PrivacyInfo.xcprivacy privacy manifest.

Three critical issues require resolution before archiving: a live Supabase JWT is committed to the git-tracked `Prod.xcconfig` (and Dev and Prod both point to the same production project), the RevenueCat production API key is an unfilled placeholder that will break the paywall at launch, and the `PrivacyInfo.xcprivacy` manifest omits fitness and health data types that the app explicitly collects — risking App Store rejection under guideline 5.1.1. Four warnings cover a missing app icon PNG (the archive will fail without it), a duplicate Core Data model file reference that risks a launch crash, a dangling `StoreKitConfigTests.swift` project reference with no backing file reference, and a script working-directory assumption in the icon generator that will produce a wrong-path failure if run from any directory other than the repo root. Three info items round out the review.

---

## Critical Issues

### CR-01: Live Supabase JWT committed to git-tracked xcconfig — both configs point to production

**File:** `Config/Prod.xcconfig:4-5`
**Issue:** `Config/Prod.xcconfig` is tracked by git (`git ls-files` confirms it) and contains the full production Supabase project URL and JWT anon key. The Dev config (not in this review's file list but referenced in the project) also points to the same production Supabase URL and key. This means every Debug build runs against the production database, and the credential is permanently in git history. The anon key is semi-public by design (RLS is the protection layer), but committing it means anyone with repo access has a stable copy and rotating it requires either a history rewrite or accepting that the old key remains accessible via `git log`.

**Fix (two parts):**

1. Add a `.gitignore` at the repo root and exclude the production config:
```
# .gitignore
Config/Prod.xcconfig
SubscriptionKey_3QM8JG26CT.p8
.DS_Store
```
Replace the committed file with a checked-in `.example` placeholder:
```
# Config/Prod.xcconfig.example  (commit this)
SUPABASE_URL = https://REPLACE_WITH_PROD_URL.supabase.co
SUPABASE_ANON_KEY = REPLACE_WITH_PROD_KEY
REVENUECAT_API_KEY = REPLACE_WITH_PROD_RC_KEY
```

2. Provision a separate Supabase project for development (or use `supabase start` locally), and point `Dev.xcconfig` at it so Debug builds never touch production data.

---

### CR-02: RevenueCat production API key is an unfilled placeholder — paywall will fail at launch

**File:** `Config/Prod.xcconfig:6`
**Issue:** `REVENUECAT_API_KEY = appl_REPLACE_WITH_PROD_RC_KEY` is the literal placeholder string. The Release build configuration uses `Prod.xcconfig` as its base. When `Purchases.configure(withAPIKey:)` is called with this value, RevenueCat will reject it and the subscription system will not initialise — users cannot purchase or restore. The app will fail App Store review in the subscription flow.

**Fix:** Replace with the real production iOS API key from the RevenueCat Dashboard (Project > Apps > iOS > Public API Key). The key format is `appl_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`. This key is safe to commit (it is a public API key, not a secret). If the xcconfig is moved behind `.gitignore` per CR-01, supply it via a CI environment variable instead.

Add a build phase guard script to catch a stale placeholder at archive time:
```bash
# Run Script phase, run for Release configuration only
if [ "$CONFIGURATION" = "Release" ]; then
  if [[ "${REVENUECAT_API_KEY}" == *"REPLACE"* ]]; then
    echo "error: REVENUECAT_API_KEY is still a placeholder. Set the real key before archiving."
    exit 1
  fi
fi
```

---

### CR-03: PrivacyInfo.xcprivacy omits fitness and health data types that the app collects

**File:** `WorkoutApp/PrivacyInfo.xcprivacy:9-35`
**Issue:** The manifest declares only `NSPrivacyCollectedDataTypePurchaseHistory` and `NSPrivacyCollectedDataTypeEmailAddress`. The privacy policy (Section 1 of `docs/privacy-policy.html`) explicitly states the app collects: workout history, session logs, sets/reps completed, fitness preferences (level, goals, equipment, injury notes), exercise performance data, and progress over time. Apple requires all collected data types to appear in the privacy manifest and the App Store privacy nutrition label. Omitting them risks rejection under App Store Review Guideline 5.1.1.

**Fix:** Add the missing data type entries. At minimum, add a fitness/exercise entry:
```xml
<dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypeFitnessAndExercise</string>
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
Cross-reference Apple's full list at developer.apple.com/app-store/app-privacy-details/ to confirm the correct type strings for the current SDK. Also confirm whether `NSPrivacyCollectedDataTypeHealth` or `NSPrivacyCollectedDataTypeOtherUserContent` apply to injury notes and performance tracking.

---

## Warnings

### WR-01: App icon PNG is missing — archive will fail

**File:** `WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json:4`
**Issue:** `Contents.json` declares `"filename": "AppIcon-1024.png"` but the file does not exist in the `AppIcon.appiconset/` directory. The `generate-app-icon.swift` script was created to produce this file but must be run manually first. Building an archive without the PNG will fail with an asset catalog compile error: "The app icon set … does not have a 1024×1024 app icon."

**Fix:** Run the generation script from the repo root before archiving:
```bash
swift scripts/generate-app-icon.swift
```
Verify the file is written to `WorkoutApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` and has a non-zero file size. The PNG must have no alpha channel (the script uses `CGImageAlphaInfo.noneSkipLast` — this is correct) and must be 1024×1024 pixels (the script uses `size = 1024` — this is correct).

---

### WR-02: Duplicate Core Data model file references — potential launch crash

**File:** `WorkoutApp.xcodeproj/project.pbxproj:37,63` and `:198,224`
**Issue:** Two distinct `PBXFileReference` entries for `WorkoutApp.xcdatamodeld` exist in the project:
- `B003A00000000005` (line 198)
- `B002000030000003` (line 224)

Both are included in the Sources build phase (lines 37 and 63 respectively). Compiling the same `.xcdatamodeld` twice causes Xcode to link two copies of the managed object model. The `NSManagedObjectModel` will be the last one loaded, which may differ from the one `PersistenceController` was authored against. At runtime this can produce an `NSPersistentStore` initialization failure and a crash on first launch.

**Fix:** Open the project in Xcode, locate the duplicate in the Project Navigator, and delete the unwanted reference (keep the one in the `Core/Data` group — `B003A00000000005`). Verify in `.pbxproj` afterward that only one `PBXFileReference` and one `PBXBuildFile` reference the file. Clean build and confirm Core Data loads without migration warnings.

---

### WR-03: StoreKitConfigTests.swift has no PBXFileReference — will not compile

**File:** `WorkoutApp.xcodeproj/project.pbxproj:434`
**Issue:** `StoreKitConfigTests.swift` appears in the PBXGroup list (line 434) with object ID `E7F1A2B3C4D5E6F708192021`, but no matching `PBXFileReference` entry exists in the file reference section. The object ID pattern also differs from the rest of the project (hex sequence vs. project's `B0xxxxxxxx` pattern), suggesting this entry was hand-edited or merged incorrectly. Xcode will display a broken red reference in the navigator, the file cannot be found, and the test target will fail to compile.

**Fix:** Remove the orphaned group entry and any matching Sources build phase entry. If the test file exists on disk, re-add it through Xcode's "Add Files to WorkoutApp" dialog to generate correct, consistent object IDs.

---

### WR-04: Icon generation script resolves output path from working directory — silent wrong-path failure

**File:** `scripts/generate-app-icon.swift:7,17`
**Issue:** Line 17 sets `outputPath` as a bare relative path:
```swift
let outputPath = "WorkoutApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
```
This path is resolved relative to the shell's working directory at the time the script runs, not relative to the script file's location. If the script is invoked from any directory other than the repo root (e.g., `swift ./scripts/generate-app-icon.swift` from within `scripts/`), the PNG will be written to a different location or the `CGImageDestinationCreateWithURL` call will fail. The error message will name the wrong absolute path, making the failure hard to diagnose. Additionally, the header comment on line 7 uses a capital `S` in `Scripts/` which does not match the actual lowercase `scripts/` directory name.

**Fix:** Derive the output path from `#file` so the script is location-independent:
```swift
let scriptDir  = URL(fileURLWithPath: #file).deletingLastPathComponent()
let repoRoot   = scriptDir.deletingLastPathComponent()
let outputPath = repoRoot
    .appendingPathComponent("WorkoutApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
    .path
```
Fix the comment on line 7:
```swift
//   swift scripts/generate-app-icon.swift
```

---

## Info

### IN-01: .p8 private key file is untracked but sitting in the repo root with no .gitignore protection

**File:** `SubscriptionKey_3QM8JG26CT.p8` (repo root, untracked)
**Issue:** A `.p8` private key (App Store Connect subscription status URL notification key) is present in the working directory but is not tracked by git and there is no root `.gitignore` to prevent accidental staging. A future `git add .` would commit the key. The key cannot be revoked easily once in git history.

**Fix:** Add a root-level `.gitignore` (see CR-01 fix) that includes `*.p8`. Move the `.p8` file outside the repository root or store it in a secrets manager for CI use only.

---

### IN-02: Privacy policy effective date lacks a specific day

**File:** `docs/privacy-policy.html:145,267`
**Issue:** The effective date reads "April 2026" with no specific calendar day in both the header (`<p class="effective-date">`) and the footer `<p>`. Legal best practice and GDPR require a specific date for a policy version.

**Fix:** Update to a specific date in both locations, e.g.:
```html
<p class="effective-date">Effective Date: April 28, 2026</p>
```
```html
<p>Hone - AI Workout Coach &bull; Privacy Policy &bull; Effective April 28, 2026</p>
```

---

### IN-03: ENABLE_PREVIEWS = YES left on in Release build configuration

**File:** `WorkoutApp.xcodeproj/project.pbxproj:1265`
**Issue:** `ENABLE_PREVIEWS = YES` is present in the Release target build configuration (`B001000050000040`). SwiftUI preview infrastructure is excluded from the final binary by the compiler when `SWIFT_OPTIMIZATION_LEVEL = -O`, so this does not affect the shipped binary's correctness. It does add slight overhead to Release build times.

**Fix:** Set `ENABLE_PREVIEWS = NO` in the Release target build configuration (Target > Build Settings > Enable Previews > Release row).

---

_Reviewed: 2026-04-28_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
