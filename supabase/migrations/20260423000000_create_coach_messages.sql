-- Phase 5: AI Coach Chat message persistence (CHAT-01, CHAT-03)
-- Stores all user-coach conversation messages for sync and history

create table coach_messages (
  id                      uuid primary key default gen_random_uuid(),
  user_id                 uuid not null references auth.users(id) on delete cascade,
  role                    text not null check (role in ('user', 'coach')),
  content                 text not null,
  created_at              timestamptz not null default now(),
  plan_modification_json  text,
  plan_modification_state text check (plan_modification_state in ('pending', 'confirmed', 'dismissed'))
);

-- Row Level Security: users can only read/write their own messages (D-17)
alter table coach_messages enable row level security;

create policy "user_owns_messages" on coach_messages
  for all using (auth.uid() = user_id);

-- Index for sorted history fetch with pagination (D-19)
create index idx_coach_messages_user_created on coach_messages (user_id, created_at desc);
