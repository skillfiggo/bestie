-- 1. Add columns
alter table public.chats 
add column if not exists streak_count int default 0;

alter table public.chats 
add column if not exists last_streak_update timestamp with time zone;

-- 2. Create function
create or replace function update_chat_streak(target_chat_id uuid)
returns void as $$
declare
    curr_streak int;
    last_update timestamp with time zone;
    now_ts timestamp with time zone;
    days_diff int;
begin
    select streak_count, last_streak_update into curr_streak, last_update
    from public.chats where id = target_chat_id;

    now_ts := now();
    
    if last_update is null then
        update public.chats 
        set streak_count = 1, last_streak_update = now_ts 
        where id = target_chat_id;
        return;
    end if;

    days_diff := date(now_ts) - date(last_update);

    if days_diff = 0 then
        update public.chats set last_streak_update = now_ts where id = target_chat_id;
    elsif days_diff = 1 then
        update public.chats 
        set streak_count = curr_streak + 1, last_streak_update = now_ts 
        where id = target_chat_id;
    else
        update public.chats 
        set streak_count = 1, last_streak_update = now_ts 
        where id = target_chat_id;
    end if;
end;
$$ language plpgsql security definer;
