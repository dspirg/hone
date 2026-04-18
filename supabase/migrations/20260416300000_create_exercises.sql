-- Phase 2: exercises table, RLS, indexes, seed data
-- Requirements: EXRC-01, EXRC-02, EXRC-03, EXRC-04
-- Threat: T-02-02 — no INSERT/UPDATE/DELETE policy for anon/authenticated roles (service_role only writes)

-- 1. Create exercises table
CREATE TABLE public.exercises (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name             TEXT NOT NULL,
    primary_muscle   TEXT NOT NULL
        CHECK (primary_muscle IN ('Chest','Back','Shoulders','Arms','Core','Legs','Glutes','Full Body')),
    equipment_tag    TEXT NOT NULL
        CHECK (equipment_tag IN ('Bodyweight','Dumbbells','Barbell','Machine')),
    difficulty       TEXT NOT NULL
        CHECK (difficulty IN ('Beginner','Intermediate','Advanced')),
    how_to_steps     JSONB NOT NULL DEFAULT '[]',
    form_tips        TEXT,
    mux_playback_id  TEXT,
    thumbnail_url    TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Indexes for common filter operations
CREATE INDEX idx_exercises_primary_muscle ON public.exercises(primary_muscle);
CREATE INDEX idx_exercises_equipment_tag  ON public.exercises(equipment_tag);

-- 3. Enable RLS
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

-- 4. Public read policy (CRITICAL: must include both anon AND authenticated — Pitfall 4)
-- Omitting anon causes empty exercise list for unauthenticated state
CREATE POLICY "Exercises are publicly readable"
    ON public.exercises FOR SELECT
    TO anon, authenticated
    USING (true);

-- No INSERT/UPDATE/DELETE policy for client roles — only service_role can write (T-02-02)

-- 5. Seed data: 20 exercises covering all 8 muscle groups and 4 equipment types
--    mux_playback_id is NULL for all (placeholder state — real IDs added when videos are licensed)

-- Chest
INSERT INTO public.exercises (name, primary_muscle, equipment_tag, difficulty, how_to_steps, form_tips, mux_playback_id) VALUES
('Push-Up', 'Chest', 'Bodyweight', 'Beginner',
 '["Get into a high plank with hands shoulder-width apart", "Lower your chest to just above the floor", "Keep your body in a straight line throughout", "Push back up to the starting position"]'::jsonb,
 'Avoid letting your hips sag or pike. Keep your core braced throughout the movement.',
 NULL),

('Bench Press', 'Chest', 'Barbell', 'Intermediate',
 '["Lie on the bench with feet flat on the floor", "Grip the bar just wider than shoulder-width", "Unrack and lower the bar to your chest with control", "Press the bar back up until arms are fully extended"]'::jsonb,
 'Keep your shoulder blades retracted and avoid bouncing the bar off your chest.',
 NULL),

('Dumbbell Fly', 'Chest', 'Dumbbells', 'Intermediate',
 '["Lie on a bench holding dumbbells above your chest with a slight bend in the elbows", "Lower the weights out to the sides in a wide arc", "Feel the stretch across your chest at the bottom", "Bring the weights back together at the top"]'::jsonb,
 'Maintain the slight elbow bend throughout — do not lock out or over-bend.',
 NULL);

-- Back
INSERT INTO public.exercises (name, primary_muscle, equipment_tag, difficulty, how_to_steps, form_tips, mux_playback_id) VALUES
('Pull-Up', 'Back', 'Bodyweight', 'Intermediate',
 '["Hang from the bar with palms facing away, hands shoulder-width apart", "Engage your lats and pull your chest toward the bar", "Drive your elbows down and back", "Lower yourself with control to full hang"]'::jsonb,
 'Avoid swinging or kipping. Focus on initiating the pull from your lats, not your arms.',
 NULL),

('Barbell Row', 'Back', 'Barbell', 'Intermediate',
 '["Hinge forward at the hips with a slight knee bend, back flat", "Grip the bar just outside your knees", "Pull the bar to your lower chest, leading with your elbows", "Lower the bar with control"]'::jsonb,
 'Keep your lower back flat throughout. Avoid jerking the weight up with momentum.',
 NULL),

('Lat Pulldown', 'Back', 'Machine', 'Beginner',
 '["Sit at the machine and grip the bar wider than shoulder-width", "Pull the bar down to your upper chest while leaning back slightly", "Squeeze your lats at the bottom", "Let the bar rise slowly under control"]'::jsonb,
 'Avoid pulling the bar behind your neck — this strains the cervical spine.',
 NULL);

-- Shoulders
INSERT INTO public.exercises (name, primary_muscle, equipment_tag, difficulty, how_to_steps, form_tips, mux_playback_id) VALUES
('Overhead Press', 'Shoulders', 'Barbell', 'Intermediate',
 '["Stand with feet shoulder-width apart, bar at collarbone height", "Brace your core and press the bar overhead in a straight line", "Lock out at the top with biceps near your ears", "Lower the bar back to collarbone height with control"]'::jsonb,
 'Avoid excessive lower-back arch. Squeeze your glutes to maintain a neutral spine.',
 NULL),

('Lateral Raise', 'Shoulders', 'Dumbbells', 'Beginner',
 '["Stand holding dumbbells at your sides with a slight elbow bend", "Raise the weights out to the sides until arms are parallel to the floor", "Pause briefly at the top", "Lower with control"]'::jsonb,
 'Lead with your elbows, not your wrists. Keep the movement smooth and controlled.',
 NULL);

-- Arms
INSERT INTO public.exercises (name, primary_muscle, equipment_tag, difficulty, how_to_steps, form_tips, mux_playback_id) VALUES
('Bicep Curl', 'Arms', 'Dumbbells', 'Beginner',
 '["Stand holding dumbbells at your sides, palms facing forward", "Curl the weights toward your shoulders while keeping elbows stationary", "Squeeze at the top", "Lower slowly back to the start"]'::jsonb,
 'Avoid swinging your torso to generate momentum. Keep the movement strict.',
 NULL),

('Tricep Dip', 'Arms', 'Bodyweight', 'Beginner',
 '["Sit on the edge of a bench, hands gripping the edge beside your hips", "Slide off the bench and lower your body by bending your elbows", "Lower until elbows are at roughly 90 degrees", "Push back up through your palms"]'::jsonb,
 'Keep your back close to the bench. Avoid letting your shoulders shrug up toward your ears.',
 NULL);

-- Core
INSERT INTO public.exercises (name, primary_muscle, equipment_tag, difficulty, how_to_steps, form_tips, mux_playback_id) VALUES
('Plank', 'Core', 'Bodyweight', 'Beginner',
 '["Get into a forearm plank position with elbows under shoulders", "Keep your body in a straight line from head to heels", "Brace your core as if bracing for a punch", "Hold the position while breathing steadily"]'::jsonb,
 'Avoid letting your hips sag or pike. Squeeze your glutes and quads to maintain alignment.',
 NULL),

('Russian Twist', 'Core', 'Bodyweight', 'Beginner',
 '["Sit on the floor with knees bent, leaning back slightly", "Lift your feet slightly off the ground for added challenge", "Rotate your torso from side to side", "Touch the floor beside your hips on each rotation"]'::jsonb,
 'Move your torso, not just your arms. Keep your spine tall throughout.',
 NULL);

-- Legs
INSERT INTO public.exercises (name, primary_muscle, equipment_tag, difficulty, how_to_steps, form_tips, mux_playback_id) VALUES
('Squat', 'Legs', 'Bodyweight', 'Beginner',
 '["Stand with feet shoulder-width apart, toes pointed slightly out", "Push your hips back and bend your knees to lower down", "Keep your chest tall and knees tracking over your toes", "Drive through your heels to stand back up"]'::jsonb,
 'Keep your weight in your heels and maintain a neutral spine throughout the movement.',
 NULL),

('Barbell Squat', 'Legs', 'Barbell', 'Intermediate',
 '["Position the bar on your upper traps and step back from the rack", "Stand with feet shoulder-width apart, toes out slightly", "Squat down until thighs are parallel to the floor", "Drive through your heels and stand up"]'::jsonb,
 'Brace your core hard before descending. Keep your knees tracking over your toes.',
 NULL),

('Lunges', 'Legs', 'Bodyweight', 'Beginner',
 '["Stand tall with feet together", "Step one foot forward and lower your back knee toward the floor", "Keep your front knee over your ankle", "Push through your front heel to return to standing"]'::jsonb,
 'Keep your torso upright throughout. Avoid letting your front knee cave inward.',
 NULL),

('Leg Press', 'Legs', 'Machine', 'Beginner',
 '["Sit in the leg press machine with feet hip-width apart on the platform", "Lower the platform toward your chest by bending your knees", "Stop when knees reach roughly 90 degrees", "Press the platform back up without locking out your knees"]'::jsonb,
 'Do not lock your knees at the top. Keep your lower back flat against the seat.',
 NULL);

-- Glutes
INSERT INTO public.exercises (name, primary_muscle, equipment_tag, difficulty, how_to_steps, form_tips, mux_playback_id) VALUES
('Hip Thrust', 'Glutes', 'Barbell', 'Intermediate',
 '["Sit against a bench with a barbell across your hips", "Plant your feet flat on the floor hip-width apart", "Drive your hips up until your body forms a straight line from knees to shoulders", "Lower with control and repeat"]'::jsonb,
 'Squeeze your glutes hard at the top. Keep your chin tucked to avoid over-extending your neck.',
 NULL),

('Glute Bridge', 'Glutes', 'Bodyweight', 'Beginner',
 '["Lie on your back with knees bent and feet flat on the floor", "Drive your hips up toward the ceiling", "Squeeze your glutes at the top", "Lower your hips back down with control"]'::jsonb,
 'Focus on driving through your heels, not your toes. Keep your core engaged throughout.',
 NULL);

-- Full Body
INSERT INTO public.exercises (name, primary_muscle, equipment_tag, difficulty, how_to_steps, form_tips, mux_playback_id) VALUES
('Burpee', 'Full Body', 'Bodyweight', 'Intermediate',
 '["Stand with feet shoulder-width apart", "Drop into a squat and place hands on the floor", "Jump your feet back to a plank position", "Perform a push-up, then jump your feet back to your hands", "Explosively jump up with arms overhead"]'::jsonb,
 'Move at a steady pace rather than rushing. Focus on maintaining form even when fatigued.',
 NULL),

('Mountain Climber', 'Full Body', 'Bodyweight', 'Beginner',
 '["Start in a high plank with hands under shoulders", "Drive one knee toward your chest", "Quickly switch legs in a running motion", "Keep your hips level throughout"]'::jsonb,
 'Avoid letting your hips rise. Keep your core tight and your breathing rhythmic.',
 NULL);
