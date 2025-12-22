-- Add status field to call_history table to track call state
-- This allows us to detect when one user ends the call

ALTER TABLE call_history
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

-- Add index for better query performance
CREATE INDEX IF NOT EXISTS idx_call_history_status ON call_history(status);

-- Update existing records to 'completed'
UPDATE call_history
SET status = 'completed'
WHERE status IS NULL;
