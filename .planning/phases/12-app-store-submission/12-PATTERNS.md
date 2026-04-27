# Phase 12: App Store Submission - Pattern Map

**Mapped:** 2026-04-27
**Files analyzed:** 5 (new/modified files in the codebase)
**Analogs found:** 5 / 5

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `WorkoutApp/PrivacyInfo.xcprivacy` | config | — | `WorkoutApp/WorkoutApp.entitlements` | role-match (both are XML plist declarations added to app target) |
| `WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json` | config | — | `WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json` (modify existing) | exact (file already exists, needs filename key added) |
| `Config/Prod.xcconfig` | config | — | `Config/Dev.xcconfig` | exact (same structure, same keys, different values) |
| `docs/privacy-policy.html` | utility | — | none in codebase (no HTML files exist) | none |
| `WorkoutApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` | config | — | `WorkoutApp/Features/Coach/Components/HoneAvatarView.swift` | partial (gradient color reference only) |

---

## Pattern Assignments

### `WorkoutApp/PrivacyInfo.xcprivacy` (config — XML plist, new file)

**Analog:** `WorkoutApp/WorkoutApp.entitlements`

**File structure pattern** — entitlements uses same XML plist format as PrivacyInfo.xcprivacy:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
</dict>
</plist>
```
Source: `WorkoutApp/WorkoutApp.entitlements` (full file)

**Full PrivacyInfo.xcprivacy content to create:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypePurchaseHistory</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeEmailAddress</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

**Xcode integration requirement:** When creating this file via File → New → File → "Privacy Manifest", the `WorkoutApp` target checkbox MUST be checked. After creation, verify the file appears in Build Phases → Copy Bundle Resources — not just in the project tree.

---

### `WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json` (config — modify existing)

**Analog:** `WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json` (the file itself)

**Current state** (lines 1-13 of existing file):
```json
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```
Source: `WorkoutApp/Assets.xcassets/AppIcon.appiconset/Contents.json` (full file)

**Target state after adding PNG** — add `"filename"` key to the existing images entry:
```json
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**PNG requirements for `AppIcon-1024.png`:**
- Exactly 1024x1024 pixels
- RGB color space, no alpha channel (alpha = App Store rejection)
- No rounded corners (iOS applies them)
- Design spec: bold "H" lettermark, amber/orange gradient (#f59e0b → #f97316) on dark background (#0a0a0a)
- Gradient direction reference: `HoneAvatarView.swift` uses `startPoint: .topLeading, endPoint: .bottomTrailing`

---

### `Config/Prod.xcconfig` (config — fill placeholders)

**Analog:** `Config/Dev.xcconfig` (exact same structure)

**Dev.xcconfig pattern** (lines 1-8 — the template to follow):
```
// Development environment configuration
// Safe to commit — contains only local dev keys (standard Supabase local dev defaults)

SUPABASE_URL = https:/$()/seuzjlqfetbefzdplulz.supabase.co
SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
REVENUECAT_API_KEY = appl_efPqktxpbrfQbXOhuUnuoGopQYa
```
Source: `Config/Dev.xcconfig` (full file, lines 1-8)

**Current Prod.xcconfig placeholders** (lines 1-8):
```
// Production environment configuration
// DO NOT COMMIT real values — replace placeholders before production build

SUPABASE_URL = REPLACE_WITH_HOSTED_URL
SUPABASE_ANON_KEY = REPLACE_WITH_HOSTED_ANON_KEY
REVENUECAT_API_KEY = appl_REPLACE_WITH_PROD_RC_KEY
```
Source: `Config/Prod.xcconfig` (full file, lines 1-8)

**Fill pattern** — replace the three placeholder values:
- `SUPABASE_URL`: Use `https:/$()/seuzjlqfetbefzdplulz.supabase.co` (same as Dev — single hosted Supabase project). Note the `https:/$()/` syntax is required: xcconfig interprets `//` as a comment start, so `$()` is a null variable expansion to escape it.
- `SUPABASE_ANON_KEY`: Copy the JWT value from Dev.xcconfig — same hosted project, same key.
- `REVENUECAT_API_KEY`: Get the production public SDK key from RevenueCat Dashboard → Project → Apps → iOS → Public API Key. It starts with `appl_` but is a DIFFERENT value from the sandbox key in Dev.xcconfig (`appl_efPqktxpbrfQbXOhuUnuoGopQYa`).

**Configuration linkage** (verified in project.pbxproj): The Release build configuration already has `baseConfigurationReference = Prod.xcconfig`. Archive runs Release. Filling this file is the only step needed for production keys to take effect.

---

### `docs/privacy-policy.html` (utility — static HTML, new file)

**Analog:** None in codebase. The `docs/` directory exists but contains only a `superpowers` subdirectory with no HTML precedent.

**No analog — use RESEARCH.md pattern.** The planner must draft this from scratch. Required content per D-14:

**Required sections:**
1. What data we collect: email address, workout history
2. How we use it: app functionality (workout plans, coach chat, progress tracking)
3. AI processing: OpenAI processes messages and workout plan generation
4. Third-party services:
   - Supabase (database and authentication) — supabase.com
   - RevenueCat (subscription management) — revenuecat.com
   - Mux (video delivery) — mux.com
5. User rights: access, correction, deletion
6. Contact information
7. Effective date

**Hosting:** GitHub Pages. URL format will be `https://<username>.github.io/privacy-policy.html` or similar. Must be HTTPS and publicly accessible — this URL is entered into App Store Connect's "Privacy Policy URL" field.

**Design guidance:** Plain, readable HTML. No framework needed. Should match brand tone — dark background (#0a0a0a), amber accent (#f59e0b) for headings if styled, or simple unstyled HTML is acceptable.

---

### `WorkoutApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (design asset — new file)

**Analog (for color/gradient reference only):** `WorkoutApp/Features/Coach/Components/HoneAvatarView.swift`

**Gradient colors extracted** (lines 7-11 of HoneAvatarView.swift):
```swift
LinearGradient(
    colors: [Theme.accent, Color(red: 0.976, green: 0.451, blue: 0.086)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```
- `Theme.accent` = `Color("AccentColor")` = `#f59e0b` (amber)
- `Color(red: 0.976, green: 0.451, blue: 0.086)` = approximately `#f97316` (orange)
- Gradient direction: top-left to bottom-right

**Icon spec:**
- Background: `#0a0a0a` (near-black, from `Theme.background` = `Color("AppBackground")`)
- Lettermark: bold "H" in amber→orange gradient (#f59e0b → #f97316), top-leading to bottom-trailing
- Style reference: Halide / Headspace — clean lettermark, not illustrative
- Canvas: 1024x1024, RGB, no alpha, no rounded corners

**This is a design artifact, not code.** Create in Figma, Sketch, or any pixel-accurate design tool. Export at 1x as PNG.

---

## Shared Patterns

### XML Plist Format
**Source:** `WorkoutApp/WorkoutApp.entitlements` (full file)
**Apply to:** `WorkoutApp/PrivacyInfo.xcprivacy`

Both files use the same Apple property list XML format with the standard DOCTYPE declaration. The entitlements file confirms Xcode's expected encoding and structure for plist files in this project.

### xcconfig Key Format
**Source:** `Config/Dev.xcconfig` (lines 1-8)
**Apply to:** `Config/Prod.xcconfig` (lines 4-8 — the placeholder lines)

Key pattern: `KEY = value` with no quotes. URL values use `https:/$()/hostname` syntax to escape double-slash comment interpretation. All three keys (SUPABASE_URL, SUPABASE_ANON_KEY, REVENUECAT_API_KEY) follow this pattern already.

### Brand Colors
**Source:** `WorkoutApp/Core/Theme.swift` (lines 3-8) and `WorkoutApp/Features/Coach/Components/HoneAvatarView.swift` (lines 7-11)
**Apply to:** `WorkoutApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`, `docs/privacy-policy.html` (if styled)

- Accent/amber: `#f59e0b` (`Theme.accent`)
- Orange: `#f97316` (rgb 0.976, 0.451, 0.086 from HoneAvatarView)
- Background: `#0a0a0a` (`Theme.background`)

---

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `docs/privacy-policy.html` | utility | — | No HTML files exist in the codebase; this is an external static web asset |

---

## Non-File Deliverables (External — No Code Analog Applies)

These deliverables are completed in external tools/services, not by editing files in the repo:

| Deliverable | Where | Key Details |
|---|---|---|
| App Store Connect app record | appstoreconnect.apple.com | Name "Hone - AI Workout Coach", bundle ID `com.danspirgen.hone` |
| Subscription products | App Store Connect → Monetization → Subscriptions | Product IDs `com.workoutapp.pro.monthly` ($12.99/mo, 14-day trial) and `com.workoutapp.pro.annual` ($79.99/yr, 14-day trial); MUST be included in the same first review submission as the app |
| RevenueCat dashboard setup | app.revenuecat.com | Connect Apple app, import products, configure "current" offering; get production public SDK key for Prod.xcconfig |
| Screenshots (6.7" and 6.1") | Design tool → App Store Connect | 1290x2796 (6.7") and 1179x2556 (6.1"); 4 screens with amber headline overlays per D-08/D-09; also produce 1320x2868 (6.9") to cover new mandatory size |
| App Store listing metadata | App Store Connect | Title, subtitle, description (warm/motivational, "Meet Hone" voice), keywords, category Health & Fitness, privacy policy URL |

**Storekit sandbox product IDs** (verified in `WorkoutApp/Configuration/WorkoutAppProducts.storekit` lines 47, 86):
- Monthly: `com.workoutapp.pro.monthly`
- Annual: `com.workoutapp.pro.annual`
- Promotional offer identifier: `monthly_50pct_3months` (50% off, 3 months, pay-as-you-go)

These exact product IDs must match what is created in App Store Connect.

---

## Metadata

**Analog search scope:** `WorkoutApp/`, `Config/`, `docs/`
**Files scanned:** 8 (Dev.xcconfig, Prod.xcconfig, Contents.json, WorkoutApp.entitlements, Theme.swift, HoneAvatarView.swift, WorkoutAppProducts.storekit, docs/ directory)
**Pattern extraction date:** 2026-04-27
