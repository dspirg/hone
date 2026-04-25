---
status: partial
phase: 08-adaptive-ai
source: [08-VERIFICATION.md]
started: "2026-04-25T15:00:00Z"
updated: "2026-04-25T15:00:00Z"
---

## Current Test

[awaiting human testing]

## Tests

### 1. Supabase schema push and Edge Function deployment
expected: `supabase db push` succeeds, `supabase functions deploy adapt-plan` and `regenerate-plan` succeed, both Active in `supabase functions list`
result: [pending]

### 2. Post-session adaptation E2E (ADPT-01, SC #1)
expected: Rate session "too hard" -> next workout shows reduced volume/intensity in TrainView with adjustment_summary banner
result: [pending]

### 3. Weekly plan evolution (ADPT-02, SC #2)
expected: After several weeks of sessions, Monday foreground check triggers weekly regeneration with plan evolution
result: [pending]

### 4. Missed session redistribution (ADPT-03, SC #3)
expected: Skip a planned training day -> remaining plan for that week redistributes exercises rather than stacking missed work
result: [pending]

### 5. Re-engagement notification tone and cap (D-08, D-09, D-10)
expected: 2+ missed sessions triggers notification with supportive tone (no guilt language), max 2 notifications/week
result: [pending]

## Summary

total: 5
passed: 0
issues: 0
pending: 5
skipped: 0
blocked: 0

## Gaps
