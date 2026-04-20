---
quick_id: 260420-a0
slug: supabase-video-pipeline
date: 2026-04-20
status: complete
duration_seconds: 196
completed_at: "2026-04-20T12:36:34Z"
tasks_completed: 3
tasks_total: 3
files_created: 4
files_modified: 2
commits:
  - 70abd29
  - 6902f82
  - ddb066f
key_decisions:
  - Added video_url alongside mux_playback_id to preserve Mux migration path
  - Upload script uses upsert-on-name to be idempotent and safe to re-run
  - Female video variants de-prioritised; standard variant URL wins on conflict
tags:
  - supabase
  - migration
  - video
  - ios-model
  - upload-script
---

# Quick Task 260420-a0: Supabase Storage Video Pipeline — Summary

**One-liner:** Postgres migration adds `video_url` + expanded equipment constraints; Node.js idempotent upload script maps 2,462 MP4s to exercises; iOS DTO/Model wired to decode and expose the new field.

## Tasks Completed

| # | Name | Commit | Key Files |
|---|------|--------|-----------|
| 1 | Database migration | 70abd29 | `supabase/migrations/20260420000000_add_video_url.sql` |
| 2 | Node.js upload script | 6902f82 | `scripts/upload-videos.mjs`, `scripts/package.json`, `scripts/README.md` |
| 3 | iOS model update | ddb066f | `WorkoutApp/Models/ExerciseDTO.swift`, `WorkoutApp/Models/ExerciseModel.swift` |

## What Was Built

### Task 1 — Migration (`20260420000000_add_video_url.sql`)

- `ADD COLUMN IF NOT EXISTS video_url TEXT` on `public.exercises`
- Dropped existing `exercises_primary_muscle_check` and `exercises_equipment_tag_check` constraints
- Re-added `primary_muscle` CHECK (same values — safe idempotent re-add)
- Re-added `equipment_tag` CHECK expanded with `'Resistance Band'`, `'Cable'`, `'Kettlebell'`

### Task 2 — Upload Script (`scripts/upload-videos.mjs`)

ES module script (Node 18+):
- Reads `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` from env or `--supabase-url` / `--supabase-key` flags
- Creates `exercise-videos` bucket (public) if absent
- Walks `videos/VERTICAL VIDEOS/` recursively for `.mp4` files
- Maps 12 folder names to `primary_muscle` values
- Derives `equipment_tag` from filename keywords (Dumbbell, Barbell, Band, Cable, Kettlebell, Machine/Smith/Suspension, else Bodyweight)
- Strips `_female`/`_Female` suffix for canonical exercise name; prefers standard over female URL
- Uploads via `storage.upload()` with `upsert: true` (safe to re-run)
- Upserts exercise rows into `public.exercises` with `onConflict: 'name'`
- `--dry-run` flag logs all actions without uploading or writing
- Prints per-file progress and final inserted/updated/errors summary
- Exits with code 1 on missing required env vars

### Task 3 — iOS Models

`ExerciseDTO.swift`:
- Added `let videoUrl: String?`
- Added `case videoUrl = "video_url"` to `CodingKeys`

`ExerciseModel.swift`:
- Added `let videoUrl: String?` stored property
- `hasVideo` updated: `muxPlaybackId != nil || videoUrl != nil`
- Memberwise init: added `videoUrl: String? = nil` parameter (default nil — backward compatible)
- `init(from dto:)`: maps `dto.videoUrl`
- `init(from entity:)`: reads `entity.value(forKey: "videoUrl") as? String`

## Decisions Made

1. **video_url alongside mux_playback_id** — keeps Mux as a future upgrade path; both fields are nullable so neither is required.
2. **Upsert on `name`** — exercise name is the natural deduplication key for the upload script; allows re-runs without duplicates.
3. **Standard variant wins over female** — when both `Exercise.mp4` and `Exercise_female.mp4` exist, the non-female URL is stored; female variants are still uploaded to storage but not referenced in the DB row.
4. **`difficulty` defaults to `Beginner`** — filenames carry no difficulty signal; rows can be updated manually in Supabase Studio after review.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

- `how_to_steps` and `form_tips` are left empty (`[]` / `NULL`) for all exercise rows created by the upload script. These must be populated via manual data entry or a follow-up import script. `hasVideo` and video playback are unaffected; only the exercise detail "how to" section will be empty for newly uploaded exercises.

## Threat Flags

None — no new network endpoints, auth paths, or trust boundary changes introduced. The upload script uses the service role key (already trusted) and only runs as a developer CLI tool, never from the iOS client.

## Self-Check: PASSED

- `supabase/migrations/20260420000000_add_video_url.sql` — FOUND
- `scripts/upload-videos.mjs` — FOUND
- `scripts/package.json` — FOUND
- `scripts/README.md` — FOUND
- `WorkoutApp/Models/ExerciseDTO.swift` — FOUND (videoUrl property + CodingKey verified)
- `WorkoutApp/Models/ExerciseModel.swift` — FOUND (videoUrl property, hasVideo updated, all three inits updated)
- Commits 70abd29, 6902f82, ddb066f — FOUND in git log
