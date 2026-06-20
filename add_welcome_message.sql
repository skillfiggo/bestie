-- ============================================
-- ADD WELCOME MESSAGE TO NEW USER SIGNUP
-- ============================================
-- This migration updates the handle_new_user() trigger to send
-- an actual welcome message into the messages table, not just
-- create the chat with a last_message placeholder.

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  team_id UUID;
  chat_id UUID;
  new_bestie_id TEXT;
BEGIN
  -- Generate unique ID
  new_bestie_id := generate_unique_bestie_id();

  -- Create Profile
  INSERT INTO public.profiles (id, name, age, gender, bestie_id, created_at, updated_at)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', 'New User'),
    COALESCE((NEW.raw_user_meta_data->>'age')::INTEGER, 18),
    COALESCE(NEW.raw_user_meta_data->>'gender', 'other'),
    new_bestie_id,
    NOW(),
    NOW()
  );

  -- Find Official Team
  BEGIN
    SELECT id INTO team_id FROM profiles WHERE name = 'Official Team' LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    team_id := NULL;
  END;

  -- Create Official Chat AND Send Welcome Message
  IF team_id IS NOT NULL AND team_id != NEW.id THEN
    BEGIN
      -- 1. Create the chat
      INSERT INTO public.chats (user1_id, user2_id, last_message, last_message_time)
      VALUES (
        NEW.id,
        team_id,
        'Welcome to Bestie! 🎉 We''re excited to have you here. This is your official support channel - feel free to reach out if you need any help!',
        NOW()
      )
      RETURNING id INTO chat_id;
      
      -- 2. Insert the actual welcome message into messages table
      INSERT INTO public.messages (
        chat_id,
        sender_id,
        receiver_id,
        content,
        message_type,
        status,
        created_at
      )
      VALUES (
        chat_id,
        team_id,  -- From Official Team
        NEW.id,   -- To new user
        'Welcome to Bestie! 🎉 We''re excited to have you here. This is your official support channel - feel free to reach out if you need any help!',
        'text',
        'sent',
        NOW()
      );
    EXCEPTION WHEN OTHERS THEN
      -- Continue if chat/message creation fails
    END;
  END IF;

  RETURN NEW;
END;
$$;

-- Note: The trigger 'on_auth_user_created' already exists and will use this updated function
