# Phase 1: Foundation - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-04-16
**Phase:** 01-foundation
**Areas discussed:** Auth screen flow, Post-auth destination, Disclaimer placement, Schema scope

---

## Auth Screen Flow

| Option | Description | Selected |
|--------|-------------|----------|
| Single screen, tab toggle | One screen with Login/Sign Up toggle. Apple Sign-In prominent above form. | ✓ |
| Separate screens | Distinct Login and Sign Up screens with navigation between them. | |

**User's choice:** Single screen, tab toggle

---

| Option | Description | Selected |
|--------|-------------|----------|
| Apple first, email secondary | Apple Sign-In is primary CTA; email/password is fallback below divider. | ✓ |
| Equal prominence | Both options at same visual weight. | |
| Email first, Apple secondary | Email/password is primary; Apple is smaller option. | |

**User's choice:** Apple first, email secondary

---

## Post-Auth Destination

| Option | Description | Selected |
|--------|-------------|----------|
| Tab bar shell | Tab bar with placeholder tabs. Sets up app navigation from Phase 1. | ✓ |
| Straight to onboarding | New users land directly in onboarding flow. | |
| Simple home screen | Single Home view; tab bar added later when phases have content. | |

**User's choice:** Tab bar shell

---

| Option | Description | Selected |
|--------|-------------|----------|
| Home | Dashboard / today's workout | ✓ |
| Workouts / Train | Exercise library, session tracking | ✓ |
| Coach / Chat | AI coach chat interface | ✓ |
| Profile / Settings | User profile, app settings | ✓ |

**User's choice:** All 4 tabs selected

---

## Disclaimer Placement

| Option | Description | Selected |
|--------|-------------|----------|
| First-launch modal | Modal sheet on first app launch. User must acknowledge. | ✓ |
| During onboarding flow | Disclaimer as a step in Phase 3 onboarding screens. | |
| Inline on auth screen | Small disclaimer text below Continue button. | |

**User's choice:** First-launch modal

---

| Option | Description | Selected |
|--------|-------------|----------|
| Hard block — must acknowledge | User taps 'I Understand' to proceed. One-time only. | ✓ |
| Dismissible | User can swipe down to dismiss. | |

**User's choice:** Hard block — must acknowledge

---

## Schema Scope

| Option | Description | Selected |
|--------|-------------|----------|
| Auth + profile only | Just users and profiles table. Later phases add their own tables. | ✓ |
| Full schema skeleton | Pre-scaffold all tables for all 8 phases now. | |
| Auth + profile + exercise tables | Middle ground — one phase ahead. | |

**User's choice:** Auth + profile only

---

| Option | Description | Selected |
|--------|-------------|----------|
| Display name | User's name for personalization | ✓ |
| Avatar URL | Profile photo (Supabase Storage) | ✓ |
| Created at / onboarding status | Track onboarding completion | ✓ |
| Subscription status | Free vs subscribed | ✓ |

**User's choice:** All 4 fields selected

---

## Claude's Discretion

- Navigation transition style for auth flow
- Exact disclaimer copy
- Keychain service name and storage keys
- Supabase client initialization strategy
- Error message copy for auth failures

## Deferred Ideas

None
