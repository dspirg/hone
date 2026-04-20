#!/usr/bin/env node
/**
 * upload-videos.mjs
 *
 * Walks videos/VERTICAL VIDEOS/, uploads each .mp4 to Supabase Storage,
 * then upserts exercise rows into public.exercises with video_url.
 *
 * Usage:
 *   node scripts/upload-videos.mjs \
 *     --videos-dir "./videos/VERTICAL VIDEOS" \
 *     --supabase-url $SUPABASE_URL \
 *     --supabase-key $SUPABASE_SERVICE_ROLE_KEY
 *     [--dry-run]
 *
 * Or set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in the environment.
 * Node 20.6+ supports --env-file flag: node --env-file=.env scripts/upload-videos.mjs
 */

import fs from 'fs';
import path from 'path';
import { createClient } from '@supabase/supabase-js';

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);

function getArg(flag) {
    const idx = args.indexOf(flag);
    return idx !== -1 ? args[idx + 1] : undefined;
}

const isDryRun = args.includes('--dry-run');
const videosDir = getArg('--videos-dir') ?? process.env.VIDEOS_DIR ?? './videos/VERTICAL VIDEOS';
const supabaseUrl = getArg('--supabase-url') ?? process.env.SUPABASE_URL;
const supabaseKey = getArg('--supabase-key') ?? process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl) {
    console.error('ERROR: Missing --supabase-url or SUPABASE_URL environment variable.');
    process.exit(1);
}
if (!supabaseKey) {
    console.error('ERROR: Missing --supabase-key or SUPABASE_SERVICE_ROLE_KEY environment variable.');
    process.exit(1);
}
if (!fs.existsSync(videosDir)) {
    console.error(`ERROR: videos directory not found: ${videosDir}`);
    process.exit(1);
}

// ---------------------------------------------------------------------------
// Supabase client
// ---------------------------------------------------------------------------
const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false },
});

// ---------------------------------------------------------------------------
// Mapping tables
// ---------------------------------------------------------------------------

/** Maps folder name to primary_muscle value */
const FOLDER_TO_MUSCLE = {
    'Abdominals': 'Core',
    'Back': 'Back',
    'Biceps': 'Arms',
    'Calisthenics-Cardio-Plyo-Functional': 'Full Body',
    'Chest': 'Chest',
    'Forearms': 'Arms',
    'Legs': 'Legs',
    'Powerlifting': 'Full Body',
    'Shoulders': 'Shoulders',
    'Stretching - Mobility': 'Full Body',
    'Triceps': 'Arms',
    'Yoga': 'Full Body',
};

/** Returns equipment_tag from filename keywords (checked in priority order) */
function deriveEquipmentTag(filename) {
    const lower = filename.toLowerCase();
    if (lower.includes('dumbbell')) return 'Dumbbells';
    if (lower.includes('barbell') || lower.includes('sandbag') || lower.includes('plate')) return 'Barbell';
    if (lower.includes('band')) return 'Resistance Band';
    if (lower.includes('cable')) return 'Cable';
    if (lower.includes('kettlebell')) return 'Kettlebell';
    if (lower.includes('machine') || lower.includes('smith') || lower.includes('suspension')) return 'Machine';
    return 'Bodyweight';
}

/** Strips _female / _Female suffix (before .mp4) to get canonical exercise name */
function canonicalName(basename) {
    // basename is the filename without extension
    return basename.replace(/_[Ff]emale$/, '').trim();
}

/** Convert a filename (no extension) to a human-readable display name */
function displayName(basename) {
    return basename.replace(/_/g, ' ').replace(/-/g, ' ').trim();
}

// ---------------------------------------------------------------------------
// Recursive directory walker — returns array of absolute file paths for .mp4
// ---------------------------------------------------------------------------
function walkDir(dir) {
    const results = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        const full = path.join(dir, entry.name);
        if (entry.isDirectory()) {
            results.push(...walkDir(full));
        } else if (entry.isFile() && entry.name.toLowerCase().endsWith('.mp4')) {
            results.push(full);
        }
    }
    return results;
}

// ---------------------------------------------------------------------------
// Ensure storage bucket exists
// ---------------------------------------------------------------------------
async function ensureBucket(bucketName) {
    const { data: buckets, error: listErr } = await supabase.storage.listBuckets();
    if (listErr) throw new Error(`listBuckets failed: ${listErr.message}`);

    const exists = buckets.some(b => b.name === bucketName);
    if (exists) {
        console.log(`Bucket "${bucketName}" already exists.`);
        return;
    }

    if (isDryRun) {
        console.log(`[DRY-RUN] Would create bucket "${bucketName}" (public: true)`);
        return;
    }

    const { error: createErr } = await supabase.storage.createBucket(bucketName, { public: true });
    if (createErr) throw new Error(`createBucket failed: ${createErr.message}`);
    console.log(`Created bucket "${bucketName}".`);
}

// ---------------------------------------------------------------------------
// Upload single file, return public URL
// ---------------------------------------------------------------------------
async function uploadFile(bucketName, storagePath, localPath) {
    const fileBuffer = fs.readFileSync(localPath);
    const { error } = await supabase.storage
        .from(bucketName)
        .upload(storagePath, fileBuffer, {
            contentType: 'video/mp4',
            upsert: true,
        });
    if (error) throw new Error(`upload failed for ${storagePath}: ${error.message}`);

    const { data: urlData } = supabase.storage
        .from(bucketName)
        .getPublicUrl(storagePath);

    return urlData.publicUrl;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
    const BUCKET = 'exercise-videos';

    console.log(`Mode: ${isDryRun ? 'DRY-RUN (no uploads or DB writes)' : 'LIVE'}`);
    console.log(`Videos dir: ${path.resolve(videosDir)}`);
    console.log('');

    const allMp4s = walkDir(videosDir);
    console.log(`Found ${allMp4s.length} .mp4 files.`);
    console.log('');

    if (!isDryRun) {
        await ensureBucket(BUCKET);
    } else {
        console.log(`[DRY-RUN] Would ensure bucket "${BUCKET}" exists.`);
    }

    // Build deduplication map: canonicalName -> { standard?: entry, female?: entry }
    // "standard" = no _female suffix; "female" = has _female suffix.
    // Prefer standard over female.
    const dedupeMap = new Map();

    for (const filePath of allMp4s) {
        const folder = path.basename(path.dirname(filePath));
        const filename = path.basename(filePath);
        const basenameNoExt = path.basename(filename, '.mp4');
        const isFemale = /_[Ff]emale$/.test(basenameNoExt);
        const canon = canonicalName(basenameNoExt);
        const primaryMuscle = FOLDER_TO_MUSCLE[folder];

        if (!primaryMuscle) {
            console.warn(`WARN: No muscle mapping for folder "${folder}", skipping "${filename}"`);
            continue;
        }

        const equipmentTag = deriveEquipmentTag(basenameNoExt);
        const storagePath = `${folder}/${filename}`;

        const entry = { filePath, filename, basenameNoExt, folder, canon, isFemale, primaryMuscle, equipmentTag, storagePath };

        if (!dedupeMap.has(canon)) {
            dedupeMap.set(canon, { standard: null, female: null });
        }
        const slot = dedupeMap.get(canon);
        if (isFemale) {
            slot.female = entry;
        } else {
            slot.standard = entry;
        }
    }

    console.log(`Unique exercises (after deduplication): ${dedupeMap.size}`);
    console.log('');

    let inserted = 0;
    let updated = 0;
    let skipped = 0;
    let errors = 0;
    let processed = 0;
    const total = dedupeMap.size;

    for (const [canon, { standard, female }] of dedupeMap) {
        processed++;
        // Prefer standard; fall back to female
        const entry = standard ?? female;

        process.stdout.write(`[${processed}/${total}] ${entry.filename} ... `);

        if (isDryRun) {
            const name = displayName(canon);
            console.log(`[DRY-RUN] Would upload "${entry.storagePath}" and upsert exercise "${name}" (${entry.primaryMuscle} / ${entry.equipmentTag})`);
            skipped++;
            continue;
        }

        try {
            const videoUrl = await uploadFile(BUCKET, entry.storagePath, entry.filePath);

            const exerciseName = displayName(canon);
            const row = {
                name: exerciseName,
                primary_muscle: entry.primaryMuscle,
                equipment_tag: entry.equipmentTag,
                difficulty: 'Beginner', // default — no difficulty info in filename
                how_to_steps: [],
                video_url: videoUrl,
            };

            const { error: upsertErr, status } = await supabase
                .from('exercises')
                .upsert(row, { onConflict: 'name', ignoreDuplicates: false })
                .select('id');

            if (upsertErr) {
                console.error(`\nDB upsert error for "${exerciseName}": ${upsertErr.message}`);
                errors++;
                continue;
            }

            // status 201 = created, 200 = updated
            if (status === 201) {
                inserted++;
            } else {
                updated++;
            }
            console.log('OK');
        } catch (err) {
            console.error(`\nERROR: ${err.message}`);
            errors++;
        }
    }

    console.log('');
    console.log('=== Summary ===');
    if (isDryRun) {
        console.log(`Would process : ${total}`);
        console.log('(No uploads or DB writes performed — dry-run mode)');
    } else {
        console.log(`Inserted      : ${inserted}`);
        console.log(`Updated       : ${updated}`);
        console.log(`Errors        : ${errors}`);
        console.log(`Total         : ${total}`);
    }
}

main().catch(err => {
    console.error('Fatal:', err.message);
    process.exit(1);
});
