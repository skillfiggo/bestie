-- Create earnings_history table to track creator income and platform revenue
CREATE TABLE IF NOT EXISTS earnings_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    source_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    transaction_type TEXT NOT NULL, -- 'video_call', 'voice_call', 'gift'
    coins_spent INT NOT NULL CHECK (coins_spent >= 0),
    diamonds_earned INT NOT NULL CHECK (diamonds_earned >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Index for faster profile lookups
    CONSTRAINT fk_creator FOREIGN KEY (creator_id) REFERENCES profiles(id),
    CONSTRAINT fk_source FOREIGN KEY (source_user_id) REFERENCES profiles(id)
);

-- Enable RLS on earnings_history
ALTER TABLE earnings_history ENABLE ROW LEVEL SECURITY;

-- Creators can see their own earnings
CREATE POLICY "Creators can view their own earnings" 
ON earnings_history FOR SELECT 
TO authenticated 
USING (auth.uid() = creator_id);

-- Admins can see all earnings
CREATE POLICY "Admins can view all earnings" 
ON earnings_history FOR SELECT 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() AND role = 'admin'
    )
);

-- Security Definer Function to process transfer atomically
CREATE OR REPLACE FUNCTION process_earning_transfer(
    p_sender_id UUID,
    p_receiver_id UUID,
    p_coin_amount INT,
    p_transaction_type TEXT
) RETURNS INT AS $$
DECLARE
    v_diamond_earned INT;
    v_new_balance INT;
BEGIN
    -- 1. Deduct Coins from Sender
    UPDATE profiles 
    SET coins = coins - p_coin_amount 
    WHERE id = p_sender_id AND coins >= p_coin_amount
    RETURNING coins INTO v_new_balance;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient coins';
    END IF;

    -- 2. Calculate the 0.4 Rate (40% Share for Creator)
    v_diamond_earned := floor(p_coin_amount * 0.4);

    -- 3. Credit Diamonds to Creator (Receiver)
    UPDATE profiles 
    SET diamonds = diamonds + v_diamond_earned 
    WHERE id = p_receiver_id;

    -- 4. Record Transaction for Transparency
    INSERT INTO earnings_history (
        creator_id, 
        source_user_id, 
        transaction_type, 
        coins_spent, 
        diamonds_earned
    ) VALUES (
        p_receiver_id, 
        p_sender_id, 
        p_transaction_type, 
        p_coin_amount, 
        v_diamond_earned
    );

    RETURN v_new_balance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
