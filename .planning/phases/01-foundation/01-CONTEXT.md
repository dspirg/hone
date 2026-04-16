# Phase 1: Foundation - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase delivers a working iOS app with:
- User authentication (email/password + Apple Sign-In)
- Persistent sessions (JWT stored in Keychain)
- Password reset via email
- A tab bar shell with placeholder tabs for future phases
- First-launch physician-consult disclaimer
- AI safety guardrails in the system prompt
- Supabase backend with auth and profiles schema

No workout content, no AI features, no exercise data in this phase — those belong to Phases 2–8.

</domain>

<decisions>
## Implementation Decisions

### Authentication Screen

- **D-01:** Single-screen auth with a Login / Sign Up tab toggle. One screen handles both states with a toggle at the top.
- **D-02:** Apple Sign-In is the primary CTA — displayed above the email/password form with a clear "or" divider between them. Apple first, email secondary.
- **D-03:** "Forgot password?" link is visible on the login state below the Continue button.

### Post-Auth Destination

- **D-04:** After sign-in or sign-up, user lands on a tab bar shell with 4 tabs: Home, Train (Workouts), Coach (AI Chat), and Profile (Settings). Tabs display appropriate empty states until future phases populate them.
- **D-05:** Home tab shows a simple "Welcome, [Name]!" message with a placeholder indicating the workout plan is coming.

### Physician-Consult Disclaimer (SAFE-01)

- **D-06:** Disclaimer appears as a modal sheet on first app launch — before any content is shown, before authentication.
- **D-07:** Hard block — user must tap "I Understand" to proceed. One-time only (acknowledged state stored in UserDefaults). Satisfies App Store Guideline 1.4.1.

### Database Schema

- **D-08:** Phase 1 creates only auth (via Supabase Auth) and a `profiles` table. No exercise, workout, or session tables yet — later phases add their own.
- **D-09:** `profiles` table columns in Phase 1: `id` (FK to auth.users), `display_name`, `avatar_url`, `onboarding_completed` (bool), `subscription_status` (enum: free/subscribed), `created_at`.
- **D-10:** Row Level Security (RLS) enforced on profiles — users can only read/write their own row.

### AI Safety Guardrails (SAFE-02)

- **D-11:** A system prompt template is established in Phase 1 (even though AI features come later). It includes safety guardrails that block medical diagnosis, treatment advice, and anything that substitutes for professional medical care.
- **D-12:** Red-team test prompts are written and verified against the guardrails before any user-facing AI is live (Phase 3+).

### Claude's Discretion

- Navigation transition style (push vs modal) for auth flow — standard iOS navigation conventions
- Exact disclaimer copy — standard fitness app legal language
- Keychain service name and storage keys
- Supabase client initialization and session refresh strategy
- Error message copy for auth failures (incorrect password, email not found, etc.)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — AUTH-01 through AUTH-04, SAFE-01, SAFE-02 (all Phase 1 requirements)

### Tech Stack
- `CLAUDE.md` — Full recommended stack: SwiftUI, Swift 6, Supabase Swift SDK 2.x, KeychainAccess 4.x, MVVM (vanilla), CoreData

### No external specs yet
No ADRs or external spec docs exist for this phase — requirements fully captured in decisions above and REQUIREMENTS.md.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield iOS project. No existing code.

### Established Patterns
- None yet. Phase 1 establishes the foundational patterns that all future phases will follow.

### Integration Points
- Supabase Auth → profiles table (trigger or manual insert on sign-up)
- Keychain (via KeychainAccess) → stores Supabase JWT access token and refresh token
- UserDefaults → stores disclaimer acknowledged flag (non-sensitive, not a token)
- Tab bar root view → integration point where all future phases plug in their tab content

</code_context>

<specifics>
## Specific Ideas

- Auth screen layout: single screen, login/signup tab toggle at top, Apple Sign-In as primary CTA above "— or —" divider, email/password form below
- Tab bar: 4 tabs — Home (🏠), Train (💪), Coach (🤖), Profile (👤) — all with empty state placeholder views
- Disclaimer: modal sheet, first launch only, "I Understand" hard-block button

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-04-16*
