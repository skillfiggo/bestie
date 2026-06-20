# Fixing Payment Coin Delivery Issues

## Problem

Users make payments via Paystack that are successfully received, but coins are
not being credited to their accounts in the release APK.

## Root Causes Identified

### 1. Missing Email Column in Profiles Table

The Paystack webhook looks up users by email from the `profiles` table. If this
column is missing or not populated, the webhook cannot find the user and fails
to credit coins.

### 2. Auth.users vs Profiles Table Mismatch

When users sign up, their email is stored in `auth.users` but may not be copied
to the `profiles` table, causing webhook lookup failures.

### 3. Limited Error Logging

Without detailed logging, it's difficult to diagnose why payments succeed in
Paystack but fail to credit coins.

## Solutions Implemented

### Step 1: Run the SQL Fix Script

Execute `fix_payment_delivery.sql` in your Supabase SQL Editor:

```bash
# Navigate to Supabase Dashboard > SQL Editor
# Paste and run the contents of: fix_payment_delivery.sql
```

This script:

- ✅ Ensures the `email` column exists in the `profiles` table
- ✅ Backfills missing emails from `auth.users`
- ✅ Creates a robust user lookup function `get_user_id_by_email()`
- ✅ Adds a `payment_log` table for debugging
- ✅ Enhances the payment processing function with better error handling

### Step 2: Deploy Updated Edge Functions

Redeploy the updated Supabase Edge Functions:

```bash
# Deploy the webhook function
supabase functions deploy paystack-webhook

# Deploy the verify-payment function
supabase functions deploy verify-payment
```

### Step 3: Verify Configuration

Ensure the following environment variables are set in Supabase:

1. Go to **Project Settings > Edge Functions**
2. Verify these secrets exist:
   - `PAYSTACK_SECRET_KEY` - Your Paystack secret key
   - `SUPABASE_URL` - Auto-set by Supabase
   - `SUPABASE_SERVICE_ROLE_KEY` - Auto-set by Supabase
   - `SUPABASE_ANON_KEY` - Auto-set by Supabase

## How to Debug Failed Payments

### Check Payment Logs

Query the new `payment_log` table to see all payment attempts:

```sql
-- View recent payment attempts
SELECT * 
FROM payment_log 
ORDER BY created_at DESC 
LIMIT 20;

-- Check failed payments
SELECT * 
FROM payment_log 
WHERE success = false 
ORDER BY created_at DESC;

-- Find specific user's payment attempts
SELECT * 
FROM payment_log 
WHERE email = 'user@example.com' 
ORDER BY created_at DESC;
```

### Check Payment History

Verify if payment was actually processed:

```sql
-- Check if payment reference exists
SELECT * 
FROM payment_history 
WHERE reference = 'YOUR_PAYMENT_REFERENCE';

-- Check user's payment history
SELECT * 
FROM payment_history 
WHERE user_id = 'USER_UUID' 
ORDER BY created_at DESC;
```

### Check User Profile Email

Verify user profile has email populated:

```sql
-- Check specific user
SELECT id, email, name, coins 
FROM profiles 
WHERE id = 'USER_UUID';

-- Find users missing email
SELECT id, name, coins 
FROM profiles 
WHERE email IS NULL OR email = '';
```

### Manual Coin Credit (FOR EMERGENCY USE ONLY)

If a user paid but didn't receive coins, you can manually credit them:

```sql
-- ONLY use after verifying the Paystack payment succeeded on their dashboard
-- Replace values with actual data
SELECT process_successful_payment(
  'USER_UUID'::uuid,
  'PAYSTACK_REFERENCE',
  5000.00, -- Amount in Naira
  3000,    -- Coins to add
  'manual-credit'
);
```

## Testing the Fix

### Test 1: Verify Email Backfill

```sql
-- Count profiles with email
SELECT COUNT(*) 
FROM profiles 
WHERE email IS NOT NULL AND email != '';

-- Should match total user count
SELECT COUNT(*) 
FROM auth.users;
```

### Test 2: Test User Lookup Function

```sql
-- Replace with actual user email
SELECT get_user_id_by_email('test@example.com');
-- Should return user UUID
```

### Test 3: Make a Test Payment

1. Use a test Paystack payment (use test keys)
2. Check `payment_log` table immediately after
3. Verify coins were credited in `profiles` table
4. Check `payment_history` for the record

## Prevention Measures

### 1. Ensure Email is Always Set

The SQL script now automatically backfills emails. For new users, ensure the
signup trigger sets email:

```sql
-- This is already in your schema, but verify it exists
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_user();
```

### 2. Monitor Payment Logs

Regularly check `payment_log` for failures:

```sql
-- Daily check for failed payments
SELECT 
  p.reference,
  p.email,
  p.amount,
  p.coins,
  p.error_message,
  p.created_at
FROM payment_log p
WHERE p.success = false 
  AND p.created_at > NOW() - INTERVAL '24 hours'
ORDER BY p.created_at DESC;
```

### 3. Set Up Alerts

Consider setting up email alerts for failed payment processing (can be done via
Supabase Webhooks or Edge Functions).

## Common Issues & Solutions

### Issue: "User not found for email"

**Solution:** Run the email backfill:

```sql
UPDATE profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id 
  AND (p.email IS NULL OR p.email = '');
```

### Issue: "Duplicate key value violates unique constraint"

**Solution:** This is actually GOOD - it means the payment was already
processed. The reference is unique to prevent double-crediting.

### Issue: Webhook not receiving events

**Solution:**

1. Check Paystack Dashboard > Settings > Webhooks
2. Verify webhook URL:
   `https://YOUR_PROJECT.supabase.co/functions/v1/paystack-webhook`
3. Ensure webhook is active
4. Check webhook logs in Paystack dashboard

## Monitoring Checklist

- [ ] SQL script executed successfully
- [ ] Edge functions deployed
- [ ] Environment variables configured
- [ ] Test payment completed successfully
- [ ] Payment logs show successful entries
- [ ] User received coins in their account
- [ ] Paystack webhook delivering to correct URL
- [ ] Email column populated for all users

## Support

If issues persist after following this guide:

1. Check the `payment_log` table for specific error messages
2. Verify Paystack dashboard shows the payment as successful
3. Check Supabase Edge Function logs for errors
4. Ensure all SQL functions and tables were created correctly
