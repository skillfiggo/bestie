-- Add image_url and link_url columns to broadcasts table
alter table public.broadcasts 
add column if not exists image_url text,
add column if not exists link_url text,
add column if not exists link_text text; -- Optional text for the button

-- No new policies needed as existing policies cover "all" columns
