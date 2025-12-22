-- 1. Create the storage bucket 'chat_assets' if it doesn't exist
insert into storage.buckets (id, name, public)
values ('chat_assets', 'chat_assets', true)
on conflict (id) do nothing;

-- Removed: alter table storage.objects enable row level security;
-- (This is enabled by default and requires higher privileges to change)

-- 3. Create Policy: Allow Public Read Access
create policy "Public Access"
on storage.objects for select
using ( bucket_id = 'chat_assets' );

-- 4. Create Policy: Allow Authenticated Uploads
create policy "Authenticated Uploads"
on storage.objects for insert
to authenticated
with check ( bucket_id = 'chat_assets' );

-- 5. Create Policy: Allow Users to Update/Delete their Own Files
create policy "Users can update own files"
on storage.objects for update
to authenticated
using ( bucket_id = 'chat_assets' and auth.uid() = owner );

create policy "Users can delete own files"
on storage.objects for delete
to authenticated
using ( bucket_id = 'chat_assets' and auth.uid() = owner );
