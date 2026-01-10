-- 1. Create Official Team User in Auth (Fake user for system messages)
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, aud, role, created_at, updated_at)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'official@bestie.team',
  '$2a$10$dummyhashdummyhashdummyhashdummyhashdummyhashdummyha', -- Dummy hash
  NOW(),
  'authenticated',
  'authenticated',
  NOW(),
  NOW()
) ON CONFLICT (id) DO NOTHING;

-- 2. Create Official Team Profile
INSERT INTO public.profiles (id, name, age, gender, bio, is_verified, avatar_url, role)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Official Team',
  25,
  'other',
  'Official Notifications from Bestie Team',
  TRUE,
  'https://ui-avatars.com/api/?name=Bestie+Team&background=65A30D&color=fff&size=256',
  'system'
) ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  avatar_url = EXCLUDED.avatar_url,
  is_verified = TRUE;

-- 3. Create RPC to send system messages safely
CREATE OR REPLACE FUNCTION send_official_message(
    target_user_id UUID,
    message_content TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with admin privileges to bypass RLS if needed
AS $$
DECLARE
    official_id UUID := '00000000-0000-0000-0000-000000000001';
    chat_id UUID;
BEGIN
    -- 1. Check if chat exists (in either direction)
    SELECT id INTO chat_id
    FROM chats
    WHERE (user1_id = official_id AND user2_id = target_user_id)
       OR (user1_id = target_user_id AND user2_id = official_id)
    LIMIT 1;

    -- 2. If no chat, create one
    IF chat_id IS NULL THEN
        INSERT INTO chats (user1_id, user2_id, last_message, last_message_time)
        VALUES (official_id, target_user_id, 'Chat started', NOW())
        RETURNING id INTO chat_id;
    END IF;

    -- 3. Insert Message
    INSERT INTO messages (chat_id, sender_id, receiver_id, content, message_type, status)
    VALUES (
        chat_id,
        official_id,
        target_user_id,
        message_content,
        'text',
        'sent'
    );

    -- 4. Update Chat Last Message
    UPDATE chats
    SET last_message = message_content,
        last_message_time = NOW()
    WHERE id = chat_id;

    RETURN jsonb_build_object('success', true, 'chat_id', chat_id);
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', SQLERRM);
END;
$$;
