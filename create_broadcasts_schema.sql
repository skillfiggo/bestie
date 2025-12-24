-- Create broadcasts table
create table public.broadcasts (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  message text not null,
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  created_by uuid references public.profiles(id)
);

-- Enable RLS
alter table public.broadcasts enable row level security;

-- Policy: Everyone can read active broadcasts
create policy "Everyone can read active broadcasts"
  on public.broadcasts for select
  using (is_active = true);

-- Policy: Admins can manage broadcasts (insert, update, delete, select all)
create policy "Admins can manage broadcasts"
  on public.broadcasts for all
  using (
    auth.uid() in (select id from public.profiles where role = 'admin')
  );

-- Admin check for verify if needed
-- (The above policy assumes 'role' column acts as the source of truth)
