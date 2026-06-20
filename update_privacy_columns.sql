-- Add privacy settings columns to profiles table

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS allow_messages_from TEXT DEFAULT 'everyone',
ADD COLUMN IF NOT EXISTS allow_calls_from TEXT DEFAULT 'everyone',
ADD COLUMN IF NOT EXISTS read_receipts BOOLEAN DEFAULT TRUE;
