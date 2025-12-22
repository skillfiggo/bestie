-- Enable RLS
ALTER TABLE call_history ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can insert their own calls" ON call_history;
DROP POLICY IF EXISTS "Users can view their own calls" ON call_history;
DROP POLICY IF EXISTS "Users can update their own calls" ON call_history;

-- Create comprehensive policies

-- 1. VIEW: Users can see calls where they are caller OR receiver
CREATE POLICY "Users can view their own calls"
ON call_history FOR SELECT
USING (
  auth.uid() = caller_id OR auth.uid() = receiver_id
);

-- 2. INSERT: Users can create calls (usually as caller)
CREATE POLICY "Users can insert their own calls"
ON call_history FOR INSERT
WITH CHECK (
  auth.uid() = caller_id
);

-- 3. UPDATE: Both Caller and Receiver can update (e.g. to set status = 'ended')
CREATE POLICY "Users can update their own calls"
ON call_history FOR UPDATE
USING (
  auth.uid() = caller_id OR auth.uid() = receiver_id
);
