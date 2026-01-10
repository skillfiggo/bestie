-- Withdrawal system for creators
CREATE TYPE withdrawal_status AS ENUM ('pending', 'approved', 'rejected', 'processing', 'completed', 'failed');

CREATE TABLE IF NOT EXISTS withdrawal_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount_diamonds INT NOT NULL CHECK (amount_diamonds >= 100),
    amount_naira DECIMAL(12, 2) NOT NULL,
    bank_name TEXT NOT NULL,
    account_number TEXT NOT NULL,
    account_name TEXT NOT NULL,
    bank_code TEXT NOT NULL,
    status withdrawal_status DEFAULT 'pending',
    paystack_transfer_code TEXT,
    admin_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE withdrawal_requests ENABLE ROW LEVEL SECURITY;

-- Users can view their own requests
CREATE POLICY "Users can view their own withdrawal requests" 
ON withdrawal_requests FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

-- Admins can view and update all requests
CREATE POLICY "Admins can manage all withdrawal requests" 
ON withdrawal_requests FOR ALL 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- Function to submit a withdrawal request atomically
CREATE OR REPLACE FUNCTION submit_withdrawal_request(
    p_user_id UUID,
    p_amount_diamonds INT,
    p_amount_naira DECIMAL,
    p_bank_name TEXT,
    p_account_number TEXT,
    p_account_name TEXT,
    p_bank_code TEXT
) RETURNS UUID AS $$
DECLARE
    v_request_id UUID;
BEGIN
    -- 1. Verify and deduct diamonds
    UPDATE profiles 
    SET diamonds = diamonds - p_amount_diamonds 
    WHERE id = p_user_id AND diamonds >= p_amount_diamonds;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient diamond balance';
    END IF;

    -- 2. Create the request
    INSERT INTO withdrawal_requests (
        user_id,
        amount_diamonds,
        amount_naira,
        bank_name,
        account_number,
        account_name,
        bank_code,
        status
    ) VALUES (
        p_user_id,
        p_amount_diamonds,
        p_amount_naira,
        p_bank_name,
        p_account_number,
        p_account_name,
        p_bank_code,
        'pending'
    ) RETURNING id INTO v_request_id;

    RETURN v_request_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Admin helper to refund/increment diamonds
CREATE OR REPLACE FUNCTION increment_diamonds(
    p_user_id UUID,
    p_amount INT
) RETURNS void AS $$
BEGIN
    UPDATE profiles 
    SET diamonds = diamonds + p_amount 
    WHERE id = p_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
