# Scripts

Utility scripts for the WorkoutApp backend.

## upload-videos.mjs

Walks `videos/VERTICAL VIDEOS/`, uploads each `.mp4` to Supabase Storage
(`exercise-videos` bucket), then upserts exercise rows into `public.exercises`
with the resulting `video_url`.

### Prerequisites

```bash
cd scripts
npm install
```

Or install globally / from the repo root if you already have `@supabase/supabase-js`.

### Usage

```bash
node scripts/upload-videos.mjs \
  --videos-dir "./videos/VERTICAL VIDEOS" \
  --supabase-url "$SUPABASE_URL" \
  --supabase-key "$SUPABASE_SERVICE_ROLE_KEY"
```

Or export the environment variables and omit the flags:

```bash
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

node scripts/upload-videos.mjs --videos-dir "./videos/VERTICAL VIDEOS"
```

Node 20.6+ supports `--env-file`:

```bash
node --env-file=.env scripts/upload-videos.mjs --videos-dir "./videos/VERTICAL VIDEOS"
```

### Dry run (no uploads, no DB writes)

```bash
node scripts/upload-videos.mjs \
  --videos-dir "./videos/VERTICAL VIDEOS" \
  --supabase-url "$SUPABASE_URL" \
  --supabase-key "$SUPABASE_SERVICE_ROLE_KEY" \
  --dry-run
```

### What it does

1. Creates the `exercise-videos` Supabase Storage bucket if it does not exist (public).
2. Walks `videos/VERTICAL VIDEOS/` recursively for `.mp4` files.
3. Derives `primary_muscle` from the parent folder name (see mapping table below).
4. Derives `equipment_tag` from filename keywords (see mapping table below).
5. Strips `_female`/`_Female` suffix to get the canonical exercise name.
6. Deduplicates: when both a standard and `_female` variant exist, uses the standard URL.
7. Uploads each file to `exercise-videos/{folder}/{filename}` (upsert — safe to re-run).
8. Upserts each exercise into `public.exercises` with `conflict on name`.
9. Prints a final summary of inserted / updated / error counts.

### Folder → primary_muscle mapping

| Folder | primary_muscle |
|--------|---------------|
| Abdominals | Core |
| Back | Back |
| Biceps | Arms |
| Calisthenics-Cardio-Plyo-Functional | Full Body |
| Chest | Chest |
| Forearms | Arms |
| Legs | Legs |
| Powerlifting | Full Body |
| Shoulders | Shoulders |
| Stretching - Mobility | Full Body |
| Triceps | Arms |
| Yoga | Full Body |

### Filename keyword → equipment_tag mapping

| Keyword | equipment_tag |
|---------|--------------|
| Dumbbell | Dumbbells |
| Barbell, Sandbag, Plate | Barbell |
| Band | Resistance Band |
| Cable | Cable |
| Kettlebell | Kettlebell |
| Machine, Smith, Suspension | Machine |
| (none of above) | Bodyweight |

### Notes

- The script is idempotent: re-running it will upsert (not duplicate) existing exercises.
- `difficulty` defaults to `Beginner` for all uploaded exercises; update individual
  rows in Supabase Studio or via a follow-up migration after manual review.
- `how_to_steps` and `form_tips` are left empty; populate them separately.
- Only the `service_role` key can write to `public.exercises` (RLS policy).
