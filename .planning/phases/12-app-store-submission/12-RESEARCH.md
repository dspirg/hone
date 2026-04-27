# Phase 12: App Store Submission - Research

**Researched:** 2026-04-27
**Domain:** iOS App Store distribution — code signing, privacy manifest, metadata, screenshots, subscription products
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**App Icon (SHIP-01)**
- D-01: Bold "H" lettermark in amber/orange gradient (#f59e0b → #f97316) on dark background (#0a0a0a). Typographic style inspired by Halide/Headspace.
- D-02: 1024x1024 PNG, no transparency, no alpha channel. Add to `WorkoutApp/Assets.xcassets/AppIcon.appiconset/`.

**Store Listing (SHIP-06)**
- D-03: App name: "Hone - AI Workout Coach"
- D-04: Subtitle: "Custom plans that adapt to you"
- D-05: Description tone: warm & motivational, "Meet Hone" voice.
- D-06: Category: Health & Fitness
- D-07: Keywords: AI workout, personal trainer, custom workout plan, adaptive fitness, workout coach, exercise tracker

**Screenshots (SHIP-05)**
- D-08: 4 screenshots — (1) Home screen, (2) AI coach chat, (3) Active session, (4) Session summary + PRs
- D-09: Marketing text overlays with amber headlines on dark background:
  1. "Your workout, ready to go"
  2. "Meet Hone, your AI coach"
  3. "Guided sessions, every rep"
  4. "Track your progress"
- D-10: Screenshots for 6.7" (iPhone 15 Pro Max / 16 Pro Max) and 6.1" (iPhone 15 Pro / 16 Pro)

**Privacy & Compliance (SHIP-02)**
- D-11: Create PrivacyInfo.xcprivacy declaring NSPrivacyAccessedAPICategoryUserDefaults (RevenueCat caching). Check for additional RC declarations.
- D-12: No ATT prompt — no cross-app tracking, no IDFA
- D-13: No tracking domains to declare
- D-14: Privacy policy — static HTML on GitHub Pages. Must cover: email, workout history, OpenAI, Supabase, RevenueCat, Mux

**Code Signing (SHIP-04)**
- D-15: Development team 34A8GVG694, automatic signing. Verify archive build succeeds. Fill Prod.xcconfig with real Supabase and RevenueCat prod keys before distribution build.

**StoreKit Products (SHIP-03)**
- D-16: Verify RevenueCat product IDs match App Store Connect. Sandbox key in Dev.xcconfig — production key goes in Prod.xcconfig.

### Claude's Discretion
- Privacy policy page design and hosting approach (as long as it covers required topics)
- Exact keyword list (optimize for ASO based on competition analysis)
- Screenshot device frame style (standard Apple frames or frameless)
- Description paragraph structure and exact copy (follow warm/motivational tone per D-05)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SHIP-01 | App has a 1024x1024 app icon registered in the asset catalog | AppIcon slot exists in Contents.json; needs PNG file added + filename registered |
| SHIP-02 | Privacy manifest (PrivacyInfo.xcprivacy) declares all required API usage and tracking domains | File does not exist yet; must be created and added to Xcode target; UserDefaults CA92.1 reason code required |
| SHIP-03 | StoreKit product IDs registered in App Store Connect matching RevenueCat configuration | Products defined in .storekit file; must be created in App Store Connect and RevenueCat dashboard |
| SHIP-04 | Development team and code signing configured for distribution builds | Automatic signing already configured; Release config already uses Prod.xcconfig; fill placeholder keys |
| SHIP-05 | App Store screenshots for 6.7" and 6.1" display sizes | 1290x2796 and 1179x2556 px dimensions confirmed valid; both sizes required |
| SHIP-06 | App Store listing complete (title, subtitle, description, keywords, category, privacy policy URL) | Metadata from CONTEXT.md decisions D-03 through D-07 ready to enter in App Store Connect |
</phase_requirements>

---

## Summary

Phase 12 is purely a packaging and compliance phase — no new features. The goal is to go from a working app to an App Store-submitted app. There are six discrete workstreams: creating the app icon, writing the privacy manifest, registering subscription products in App Store Connect, verifying the distribution build signs correctly, capturing and compositing screenshots, and filling out the App Store listing.

The project is in good shape: the Xcode project has the AppIcon slot, xcconfig files for Dev/Release, automatic signing already configured for team 34A8GVG694, RevenueCat SDK integrated with the "pro" entitlement, and the storekit sandbox configuration referencing `com.workoutapp.pro.monthly` and `com.workoutapp.pro.annual` product IDs. The main gaps are: no PrivacyInfo.xcprivacy file exists, no app icon PNG exists, Prod.xcconfig still has placeholder keys, the App Store Connect app record and subscription products have not been created, and no screenshots or App Store listing exist yet.

A critical ordering constraint: subscription products MUST be included in the same App Store Connect submission as the app itself on first submission — Apple will not review in-app purchases submitted separately on a first-time app. This means SHIP-03 must be completed before the archive is submitted for review.

**Primary recommendation:** Work in this dependency order: (1) fill Prod.xcconfig keys and verify archive builds, (2) create App Store Connect record + subscription products, (3) create PrivacyInfo.xcprivacy, (4) create app icon, (5) capture screenshots with marketing overlays, (6) fill App Store listing metadata and submit.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| App icon asset | iOS client build | — | Compiled into app binary via Xcode asset catalog |
| Privacy manifest | iOS client build | — | Bundled in .app at build time; declares what SDKs access |
| Code signing / distribution | Xcode / Apple Developer Portal | — | Certificates and provisioning managed by Apple's automatic signing |
| StoreKit product registration | App Store Connect (external) | RevenueCat Dashboard | Products live in Apple's system; RevenueCat imports them |
| Screenshots | Design artifact | App Store Connect | Created externally, uploaded to App Store Connect listing |
| App Store listing metadata | App Store Connect (external) | — | Filled in App Store Connect UI |
| Privacy policy page | Static web host (GitHub Pages) | — | Must be publicly accessible URL; referenced in App Store listing |

---

## Standard Stack

### Core (this phase has no code dependencies — all work is configuration, design, and external service setup)

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16 | Archive and distribute | Product → Archive → Distribute App → App Store Connect |
| App Store Connect | App record, metadata, subscription products, screenshots | appstoreconnect.apple.com |
| RevenueCat Dashboard | Connect Apple app, import products, get production API key | app.revenuecat.com |
| Figma / Sketch / any design tool | App icon and screenshot compositing | No specific tool required — output is PNG files |
| GitHub Pages | Host privacy policy HTML | Free, HTTPS, stable URL |

### No new Swift Package dependencies required for this phase.

---

## Architecture Patterns

### System Architecture Diagram

```
[Developer machine]
     |
     |-- 1. Fill Prod.xcconfig (Supabase URL + keys, RevenueCat prod key)
     |-- 2. Add AppIcon.png to Assets.xcassets
     |-- 3. Add PrivacyInfo.xcprivacy to Xcode target
     |-- 4. Product → Archive (Release config → Prod.xcconfig applied)
     |
     v
[Xcode Organizer]
     |
     |-- Validate App (pre-flight check)
     |-- Distribute App → App Store Connect
     |
     v
[App Store Connect]
     |-- App record (bundle ID: com.danspirgen.hone)
     |-- In-App Purchases registered (MUST be in same submission)
     |-- Screenshots uploaded (6.7" + 6.1")
     |-- Metadata filled (name, subtitle, description, keywords)
     |-- Privacy policy URL set
     |-- Build attached
     |
     v
[Submitted for Review]
```

### Recommended File Structure Changes

```
WorkoutApp/
├── Assets.xcassets/
│   └── AppIcon.appiconset/
│       ├── Contents.json          # Already exists; add filename entry
│       └── AppIcon-1024.png       # CREATE: 1024x1024 no-alpha PNG
├── PrivacyInfo.xcprivacy          # CREATE: privacy manifest
Config/
├── Prod.xcconfig                  # FILL: replace REPLACE_WITH_ placeholders
```

```
docs/                              # CREATE: GitHub Pages repo or subdirectory
└── privacy-policy.html            # CREATE: static privacy policy
```

### Pattern 1: PrivacyInfo.xcprivacy File Structure

**What:** An XML property list placed at the root of the app target that declares required-reason API usage and data collection.

**When to use:** Required for all App Store submissions since May 1, 2024. Must declare every required-reason API your app OR any SDK in your app accesses.

**Full file contents for this app:**
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

**Source:** [CITED: donnywals.com/how-to-add-a-privacy-manifest-file] and [CITED: developer.apple.com/documentation/technotes/tn3183]

**How to add to Xcode:**
- File → New → File → search "Privacy Manifest" → select template
- Name it `PrivacyInfo` (Xcode appends .xcprivacy)
- Assign to the `WorkoutApp` app target (not test targets)
- Verify it appears in the app target's "Copy Bundle Resources" build phase

**Reason code CA92.1 explanation:** Standard UserDefaults read/write access for non-App-Group scenarios. RevenueCat SDK caches subscription state in UserDefaults. `1C8F.1` is the alternative if using App Groups, which this app does not.

### Pattern 2: AppIcon Asset Catalog Registration

**Current state:** `Contents.json` has a single `"idiom": "universal", "platform": "ios", "size": "1024x1024"` entry with no `"filename"` key — meaning the slot exists but no image is assigned.

**After adding the PNG, Contents.json should be:**
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

**PNG requirements:** [CITED: developer.apple.com App Store guidelines]
- Exactly 1024x1024 pixels
- RGB color space
- No alpha channel (transparency causes rejection)
- No rounded corners (iOS applies them automatically)
- File format: PNG

### Pattern 3: Prod.xcconfig Fill-in

**Current state** (Prod.xcconfig placeholders):
```
SUPABASE_URL = REPLACE_WITH_HOSTED_URL
SUPABASE_ANON_KEY = REPLACE_WITH_HOSTED_ANON_KEY
REVENUECAT_API_KEY = appl_REPLACE_WITH_PROD_RC_KEY
```

**Required values:**
- `SUPABASE_URL`: The hosted Supabase project URL (same as Dev.xcconfig URL — `seuzjlqfetbefzdplulz.supabase.co` — since there is only one Supabase project, Dev and Prod use the same URL). [ASSUMED — the project may intend a separate prod Supabase project; verify with user]
- `SUPABASE_ANON_KEY`: The anon key for the hosted project (same project → same key for now, unless separate prod project is used)
- `REVENUECAT_API_KEY`: Production public API key from RevenueCat Dashboard → Project → Apps → iOS. Starts with `appl_`. Different from the sandbox key in Dev.xcconfig.

**Archive configuration:** Confirmed in `project.pbxproj` — Release build configuration already has `baseConfigurationReference = Prod.xcconfig`. Archive uses Release. So filling Prod.xcconfig is all that's needed for signing to work with correct keys. [VERIFIED: project.pbxproj grep]

### Pattern 4: Screenshot Dimensions and Delivery

**Confirmed valid sizes for App Store submission (2026):** [CITED: screenhance.com/blog/app-store-screenshot-dimensions-2026]
- 6.7" display (iPhone 14 Pro Max, 15 Plus, 15 Pro Max, 16 Plus, 16 Pro Max): **1290 x 2796 px** portrait
- 6.1" display (iPhone 14 Pro, 15 Pro, 16 Pro): **1179 x 2556 px** portrait

**Note on 6.9" (1320x2868):** Apple added 6.9" as the new mandatory size starting with iPhone 16 Pro Max generation. However, 6.7" screenshots are accepted and automatically scaled. To be safe and cover the full required range: upload 6.9" (1320x2868) as the primary, and optionally 6.1" (1179x2556) as secondary. [MEDIUM confidence — Apple's requirements changed in late 2024; CONTEXT.md specifies 6.7" and 6.1" which remain valid but 6.9" is now technically the primary mandatory size]

**Planner note:** CONTEXT.md D-10 specifies 6.7" and 6.1". Research indicates 6.9" is now the new primary mandatory size. Recommend producing screenshots at 6.9" (1320x2868) in addition to 6.1" (1179x2556), or flagging this discrepancy for user decision. 6.7" screenshots ARE still accepted by App Store Connect.

**File requirements:**
- Format: PNG or flattened JPEG (no transparency)
- RGB color space
- Max 10 screenshots per localization
- Max 10 MB per file
- Portrait orientation for this app

### Pattern 5: App Store Connect Subscription Product Registration

**Product IDs defined in storekit sandbox file:**
- `com.workoutapp.pro.monthly` (monthly, $12.99, 14-day free trial)
- `com.workoutapp.pro.annual` (annual, $79.99, 14-day free trial)
- Subscription group: "WorkoutApp Pro"
- Promotional offer: `monthly_50pct_3months` on monthly product (50% off for 3 months)

**CRITICAL:** On first App Store submission, in-app purchases must be included in the same review submission as the app. They will not be reviewed if submitted separately. [CITED: revenuecat.com/docs/platform-resources/apple-platform-resources/app-store-connect-setup-guide]

**Steps to register products in App Store Connect:**
1. Create app record: Apps → + → New App → enter name "Hone - AI Workout Coach", bundle ID `com.danspirgen.hone`
2. In the app record: Monetization → Subscriptions → + → create subscription group "Hone Pro"
3. Add "Pro Monthly": Product ID `com.workoutapp.pro.monthly`, price $12.99, duration 1 month, 14-day free trial
4. Add "Pro Annual": Product ID `com.workoutapp.pro.annual`, price $79.99, duration 1 year, 14-day free trial
5. Add promotional offer on monthly: identifier `monthly_50pct_3months`, pay-as-you-go, $6.49 for 3 months
6. In RevenueCat dashboard: connect Apple app → import products → configure "current" offering with annual and monthly packages

**RevenueCat production key:** RevenueCat Dashboard → Project Settings → Apps → iOS app → Public SDK Key (starts with `appl_`). This goes in Prod.xcconfig.

### Pattern 6: Privacy Policy Page (GitHub Pages)

**Minimum viable approach:**
1. Create a new public GitHub repo named `username.github.io` or add to existing one
2. Create `privacy-policy.html` with required disclosures
3. Enable GitHub Pages on the repo
4. URL becomes `https://username.github.io/privacy-policy.html` or similar

**Required content per D-14:**
- Data collected: email address, workout history
- AI processing: OpenAI processes workout plan generation and coaching messages
- Third-party services: Supabase (database and auth), RevenueCat (subscription management), Mux (video delivery)
- User rights and contact information

**App Store listing field:** "Privacy Policy URL" — must be a publicly accessible HTTPS URL, not a redirect.

### Anti-Patterns to Avoid

- **Adding PrivacyInfo.xcprivacy to project files but not assigning to app target:** The file will be in the Xcode project tree but not bundled in the .app. Always verify it appears in Build Phases → Copy Bundle Resources.
- **Using the Dev.xcconfig RevenueCat key in production:** The sandbox `appl_efPqktxpbrfQbXOhuUnuoGopQYa` key only works with RevenueCat sandbox mode. The production key is different and must be obtained from the RevenueCat dashboard after the app is registered there.
- **Submitting the app without in-app purchases in the same review:** Apple will not review standalone IAP submissions on a first-time app submission. Select IAPs to include during the App Store Connect submission flow.
- **Icon with alpha channel:** Any PNG with an alpha channel will be rejected by App Store Connect validation. Check in Xcode's asset catalog — it should show no warning about transparency.
- **StoreKit config file left attached to scheme at archive time:** The `.storekit` file is a testing aid. The scheme already routes StoreKit config to the Launch action only. Confirm the Archive action has no StoreKit config reference (currently it does not — confirmed in xcscheme file). [VERIFIED: xcscheme file shows StoreKit config in LaunchAction only, not ArchiveAction]

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Screenshot device frames | Custom frame rendering code | Figma with Apple Device Frames kit, or frameless marketing shots | Apple provides official device frame assets; frameless is simpler and App Store Connect renders device chrome automatically |
| Privacy policy legal text | Custom legal drafting | Standard template covering GDPR/CCPA basics + app-specific third parties | Privacy policies are formulaic for this type of app; a template covering the required services is sufficient |
| Receipt validation or subscription linking | Custom StoreKit flow | RevenueCat (already integrated) | RevenueCat handles all receipt validation and entitlement logic |
| Screenshot compositing at exact pixel sizes | Manual pixel counting | Figma artboard at exact dimensions (1290x2796, 1179x2556, or 1320x2868) | Design tools guarantee pixel-exact output |

---

## Common Pitfalls

### Pitfall 1: PrivacyInfo.xcprivacy target assignment
**What goes wrong:** File is added to Xcode project but not assigned to the app target. The privacy manifest is not bundled in the .app. App Store Connect upload will fail with ITMS-91053 or similar error about missing required reason declarations.
**Why it happens:** Xcode's "Add to targets" checkbox is easy to miss when creating new files.
**How to avoid:** When creating the file via File → New → File, explicitly check the `WorkoutApp` target checkbox. Afterward, confirm it appears in Build Phases → Copy Bundle Resources.
**Warning signs:** `xcodebuild archive` completes but App Store Connect shows warnings about missing privacy manifest after upload.

### Pitfall 2: RevenueCat sandbox vs. production API key mismatch
**What goes wrong:** Prod.xcconfig is filled with the sandbox API key instead of the production key. Subscription purchases fail silently or route to sandbox in production.
**Why it happens:** Both keys start with `appl_` — they look identical in format.
**How to avoid:** Get the production public SDK key explicitly from RevenueCat Dashboard → Project → Apps → iOS → Public API Key. Dev.xcconfig already has `appl_efPqktxpbrfQbXOhuUnuoGopQYa` (sandbox). The prod key will be a different value.
**Warning signs:** Live users see "Product not found" errors on purchase, or RevenueCat dashboard shows no live purchases.

### Pitfall 3: In-app purchases not included in first submission
**What goes wrong:** App is submitted for review without including the subscription products. Apple returns feedback that IAPs were not reviewed.
**Why it happens:** It is not obvious in the App Store Connect submission flow that IAPs need to be explicitly added to the submission.
**How to avoid:** During the App Store Connect submission flow, on the "Add for Review" step, explicitly add both subscription products (Pro Monthly and Pro Annual) alongside the app build.
**Warning signs:** App goes into review without IAP status changing from "Ready to Submit."

### Pitfall 4: App name too long
**What goes wrong:** "Hone - AI Workout Coach" is 21 characters — within the 30-character limit. No issue, but verify the name is not already taken in the App Store.
**How to avoid:** Check App Store Connect during app record creation — it will reject duplicate names.
**Warning signs:** Error on app record creation saying the name is taken.

### Pitfall 5: Scheme has StoreKit config attached at archive time (already confirmed non-issue)
**What goes wrong:** If the StoreKit testing config were attached to the archive scheme, production builds would use sandbox products. This would cause purchase failures in production.
**Status:** Already confirmed safe. The xcscheme has `StoreKitConfigurationFileReference` only in the `<LaunchAction>` block, not in `<ArchiveAction>`. [VERIFIED: xcscheme file contents]

### Pitfall 6: Screenshot pixel dimension not accepted
**What goes wrong:** Screenshots are close to but not exactly the required dimensions.
**How to avoid:** Use Figma artboards set to exact dimensions: 1290x2796 for 6.7", 1179x2556 for 6.1", 1320x2868 for 6.9". Export at 1x (not 2x or 3x).
**Warning signs:** App Store Connect rejects screenshots with "Screenshot dimensions are not supported."

### Pitfall 7: Supabase production key confusion
**What goes wrong:** Dev.xcconfig shows the Supabase URL already points to the hosted project (`seuzjlqfetbefzdplulz.supabase.co`) — not localhost. This means dev builds are already hitting production Supabase. Prod.xcconfig placeholders need to be filled with the same hosted URL and key, OR a separate production Supabase project needs to be created.
**Recommendation:** Fill Prod.xcconfig with the same hosted Supabase values currently in Dev.xcconfig (since they already point to the live project). [ASSUMED — if a separate production Supabase project is intended, this is a bigger task than this phase's scope]

---

## Code Examples

### PrivacyInfo.xcprivacy — complete file

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

Source: [CITED: donnywals.com/how-to-add-a-privacy-manifest-file-to-your-app-for-required-reason-api-usage]

### AppIcon Contents.json — after adding PNG

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

Source: [VERIFIED: Contents.json existing structure in codebase]

### Prod.xcconfig — filled values

```
// Production environment configuration
// DO NOT COMMIT real values — replace placeholders before production build

SUPABASE_URL = https:/$()/seuzjlqfetbefzdplulz.supabase.co
SUPABASE_ANON_KEY = <anon-key-from-supabase-dashboard>
REVENUECAT_API_KEY = appl_<prod-key-from-revenuecat-dashboard>
```

Note: The `https:/$()/` pattern is Xcode xcconfig URL syntax — the `$()` is a null variable expansion to prevent xcconfig from interpreting `//` as a comment. This syntax is already correct in Dev.xcconfig. [VERIFIED: Dev.xcconfig]

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Multiple icon sizes in asset catalog | Single 1024x1024 universal icon | Xcode 14+ (2022) | Simpler — only one size needed |
| Required 5.5" screenshots for submission | 6.9" or 6.7" screenshots cover all devices | Late 2024 (iPhone 16 Pro Max launch) | Older 5.5" screenshots no longer needed; 6.9" is now technically the primary mandatory size |
| Manual code signing with distribution certificates | Automatic signing for distribution | Xcode 8+ (mature) | Xcode manages distribution cert and provisioning profile automatically |
| Privacy manifest not required | PrivacyInfo.xcprivacy required for all submissions | May 1, 2024 | Every app must declare required-reason API usage |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Prod.xcconfig should use same Supabase URL/key as Dev.xcconfig (single hosted project) | Pattern 3, Pitfall 7 | If a separate production Supabase project is intended, keys must be sourced from that project instead |
| A2 | RevenueCat purchase history is the primary data collection to declare in NSPrivacyCollectedDataTypes | PrivacyInfo.xcprivacy code example | May need to add additional data types if Supabase Auth SDK also accesses required-reason APIs |
| A3 | Screenshot sizes: 6.9" (1320x2868) is the primary mandatory size; 6.1" (1179x2556) as secondary (RESOLVED) | Screenshots section | N/A — user confirmed 6.9" as primary, dropping 6.7" since 6.9" covers that device class |

---

## Open Questions (RESOLVED)

1. **Supabase: single project or separate prod project?** (RESOLVED)
   - What we know: Dev.xcconfig points to the hosted Supabase project `seuzjlqfetbefzdplulz.supabase.co` — not localhost.
   - Resolution: Plans use same Supabase values as Dev — treat as the production project. Prod.xcconfig filled identically.

2. **Screenshot primary size: 6.7" or 6.9"?** (RESOLVED)
   - Resolution: User decided to add 6.9" (1320x2868) as the primary mandatory size. Produce 6.9" + 6.1" (1179x2556). Drop 6.7" since 6.9" covers that device class.

3. **Supabase SDK privacy manifest — does it bundle its own?** (RESOLVED)
   - Resolution: Treat as post-archive validation. After adding PrivacyInfo.xcprivacy and running an archive, check App Store Connect validation output. If ITMS-91053 errors appear for categories not yet declared, add them.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode | Archive build | ✓ | 16 (confirmed by scheme LastUpgradeVersion = "1630") | — |
| Apple Developer Account | Code signing, App Store Connect | ✓ | Active (team 34A8GVG694 confirmed in project) | — |
| App Store Connect account | App record creation | ✓ (assumed same account as dev team) | — | — |
| RevenueCat dashboard access | Production API key | ✓ (SDK already integrated with sandbox key) | SDK 5.x | — |
| Design tool (Figma/etc.) | App icon, screenshots | [ASSUMED available] | Any | Sketch, Photoshop, or any pixel-accurate export tool |
| GitHub account | Privacy policy hosting | [ASSUMED available] | — | Netlify drop, Supabase Storage public bucket |

**Missing dependencies with no fallback:** None identified — all critical tooling is confirmed available.

**Missing dependencies with fallback:** Design tool and GitHub for hosting are assumed available but have viable fallbacks.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Swift) |
| Config file | Xcode scheme (shouldAutocreateTestPlan = "YES") |
| Quick run command | `xcodebuild test -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16'` |
| Full suite command | Same as above |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SHIP-01 | Icon PNG present in asset catalog, no missing icon warning | Build validation | `xcodebuild build -scheme WorkoutApp` (warning check) | ❌ Wave 0: manual verification |
| SHIP-02 | PrivacyInfo.xcprivacy present and in Copy Bundle Resources | Build + manual | `xcodebuild archive` then App Store Connect validation | ❌ Wave 0: manual |
| SHIP-03 | StoreKit product IDs registered and match RevenueCat config | Manual | RevenueCat dashboard verification | Manual-only: requires external service state |
| SHIP-04 | Archive build succeeds with distribution signing | Build validation | `xcodebuild archive -scheme WorkoutApp -configuration Release` | ❌ Wave 0: add archive build check |
| SHIP-05 | Screenshots exist at correct dimensions | Manual | Visual inspection | Manual-only: design artifact |
| SHIP-06 | App Store listing complete in App Store Connect | Manual | App Store Connect UI review | Manual-only: external service |

### Sampling Rate

- **Per task commit:** `xcodebuild build -scheme WorkoutApp -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | grep -E "error:|warning:"` — catch build regressions
- **Per wave merge:** `xcodebuild archive -scheme WorkoutApp -configuration Release` — full distribution build check
- **Phase gate:** Distribution archive completes without errors; App Store Connect validation passes; all 4 screenshots uploaded; all listing fields complete

### Wave 0 Gaps

- [ ] Archive build smoke test command — verify `xcodebuild archive` runs cleanly with Prod.xcconfig filled
- [ ] Asset catalog warning check — no missing icon warnings after AppIcon-1024.png added

*(Most SHIP requirements are manual/external — automated tests are limited to build system verification)*

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No (no new auth code in this phase) | — |
| V3 Session Management | No | — |
| V4 Access Control | No | — |
| V5 Input Validation | No (no new input handling) | — |
| V6 Cryptography | Yes — key management | Prod keys in xcconfig, NOT hardcoded; xcconfig excluded from git via .gitignore recommended |

### Key Security Requirement: Prod.xcconfig Must Not Be Committed

The `Prod.xcconfig` currently has placeholder values and is in git. Once filled with real Supabase anon keys and RevenueCat production key, the file should either:
- Remain committed with real values (acceptable for a private repo since the Supabase anon key is semi-public by design — it's embedded in the distributed app binary anyway), OR
- Be added to .gitignore and managed via environment/CI injection

**Assessment:** Supabase anon keys and RevenueCat public SDK keys are both designed to be embedded in app binaries and are not considered secrets in the same sense as server-side keys. Committing Prod.xcconfig to a private repo is acceptable for this project. [ASSUMED — confirm repo is private]

---

## Sources

### Primary (HIGH confidence)
- [VERIFIED: project.pbxproj] — Confirmed Code_SIGN_STYLE = Automatic, DEVELOPMENT_TEAM = 34A8GVG694, Release config uses Prod.xcconfig, bundle ID com.danspirgen.hone
- [VERIFIED: Contents.json] — Confirmed AppIcon slot exists with no filename; single 1024x1024 universal entry
- [VERIFIED: xcscheme file] — Confirmed StoreKit config only in LaunchAction, not ArchiveAction; ArchiveAction uses Release config
- [VERIFIED: WorkoutAppProducts.storekit] — Product IDs com.workoutapp.pro.monthly, com.workoutapp.pro.annual confirmed with pricing and promotional offers
- [CITED: developer.apple.com/documentation/technotes/tn3183] — Required reason API entries and NSPrivacyAccessedAPICategoryUserDefaults with CA92.1 reason code
- [CITED: donnywals.com/how-to-add-a-privacy-manifest-file-to-your-app-for-required-reason-api-usage] — Complete PrivacyInfo.xcprivacy XML format and Xcode integration steps

### Secondary (MEDIUM confidence)
- [CITED: revenuecat.com/docs/platform-resources/apple-platform-resources/app-store-connect-setup-guide] — MUST include IAPs in first submission
- [CITED: screenhange.com/blog/app-store-screenshot-dimensions-2026] — 6.7" (1290x2796) and 6.1" (1179x2556) remain valid; 6.9" is optional
- [CITED: splitmetrics.com/blog/app-store-screenshots-aso-guide/] — 6.9" is the new primary mandatory size per Apple's 2024 update

### Tertiary (LOW confidence)
- [WebSearch] — App Store Connect subscription product registration steps (not verified against official Apple docs page)

---

## Metadata

**Confidence breakdown:**
- Existing project state: HIGH — verified by direct file reads
- PrivacyInfo.xcprivacy format and reason codes: HIGH — cited from Apple technote TN3183 and Donny Wals
- Screenshot dimensions: MEDIUM — confirmed valid but 6.9" requirement ambiguity flagged
- App Store Connect workflow (product creation, first submission rules): MEDIUM — multiple sources agree on MUST include IAPs rule
- Prod.xcconfig / Supabase single vs. dual project: LOW — assumed, needs user confirmation

**Research date:** 2026-04-27
**Valid until:** 2026-05-27 (App Store requirements are relatively stable; screenshot size requirements recently changed so verify 6.9" mandatory status before submission)
