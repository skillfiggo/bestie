# Function Search Path Mutable Warnings - Fix Guide

## ⚠️ What Are These Warnings?

The "Function Search Path Mutable" warnings indicate a **security vulnerability** in PostgreSQL/Supabase functions. When functions don't have a fixed `search_path`, they can be exploited through "search path attacks."

## 🔒 Security Risk

Without a fixed search_path, an attacker could:
1. Create a malicious schema
2. Create identically named tables/functions in that schema
3. Manipulate the search_path to execute their malicious code instead of yours

## ✅ The Fix

Add these two keywords to **EVERY** function definition:

```sql
CREATE OR REPLACE FUNCTION my_function()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER          -- ← Add this
SET search_path = public  -- ← Add this
AS $$
BEGIN
  -- function body
END;
$$;
```

## 📋 Functions That Need Fixing

Based on your warnings, these functions need to be updated:

1. ✅ `update_reports_updated_at`
2. ✅ `update_chat_streak`
3. ✅ `handle_new_user_minimal`
4. ✅ `handle_new_user_robust`
5. ✅ `handle_follow_change`
6. ✅ `handle_unfollow_change`
7. ✅ `handle_message_streak`
8. ✅ `process_earning_transfer`
9. ✅ `increment_moment_likes`
10. ✅ `decrement_moment_likes`
11. ✅ `decrement_likes`
12. ✅ `submit_withdrawal_request`
13. ✅ `increment_diamonds`
14. ✅ `send_official_message`

## 🚀 How to Apply the Fix

### Option 1: Run the Fix Script (Recommended)
```bash
# Connect to your Supabase database and run:
psql -h YOUR_SUPABASE_HOST -U postgres -d postgres -f fix_search_path_warnings.sql
```

Or in Supabase Dashboard:
1. Go to **SQL Editor**
2. Open `fix_search_path_warnings.sql`
3. Click **Run**

### Option 2: Manual Fix (For Individual Functions)

For each function showing the warning:
1. Find the function in your SQL files
2. Add `SECURITY DEFINER` after `LANGUAGE plpgsql`
3. Add `SET search_path = public` after `SECURITY DEFINER`
4. Re-run the CREATE statement

Example:
```sql
-- BEFORE (Insecure)
CREATE OR REPLACE FUNCTION handle_follow_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- code
END;
$$;

-- AFTER (Secure)
CREATE OR REPLACE FUNCTION handle_follow_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- code
END;
$$;
```

## 🔍 Verification

After applying the fix, verify in Supabase:

```sql
-- Check if functions have search_path set
SELECT 
  proname as function_name,
  prosecdef as is_security_definer,
  proconfig as search_path_config
FROM pg_proc 
WHERE pronamespace = 'public'::regnamespace
  AND proname IN (
    'update_reports_updated_at',
    'handle_follow_change',
    'process_earning_transfer'
    -- add others
  );
```

You should see:
- `is_security_definer` = `true`
- `search_path_config` = `{search_path=public}`

## 📚 Best Practices Going Forward

**Always include these in new functions:**

```sql
CREATE OR REPLACE FUNCTION your_new_function()
RETURNS [return_type]
LANGUAGE plpgsql
SECURITY DEFINER          -- ✅ Always add
SET search_path = public  -- ✅ Always add
AS $$
BEGIN
  -- Your code here
END;
$$;
```

## ⚡ Quick Template

Copy-paste this template for new functions:

```sql
CREATE OR REPLACE FUNCTION function_name(
  -- parameters
)
RETURNS return_type
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  -- variables
BEGIN
  -- logic
  RETURN result;
END;
$$;

COMMENT ON FUNCTION function_name() IS 'Description of what this function does';
```

## 🎯 Summary

- **What:** Add `SECURITY DEFINER SET search_path = public` to all functions
- **Why:** Prevent search path injection attacks
- **How:** Run `fix_search_path_warnings.sql` in Supabase SQL Editor
- **When:** Immediately (this is a security issue)

## 📝 Additional Notes

### SECURITY DEFINER vs SECURITY INVOKER

- **SECURITY DEFINER**: Function runs with privileges of the function owner (usually more secure for RLS)
- **SECURITY INVOKER**: Function runs with privileges of the caller

For Supabase with RLS, `SECURITY DEFINER` is usually preferred because:
1. It bypasses RLS policies (intended behavior for system functions)
2. It works consistently regardless of who calls it
3. Combined with `SET search_path`, it's secure

### Multiple Schemas

If you use multiple schemas:
```sql
SET search_path = public, auth, extensions
```

But for most Supabase projects, `public` is sufficient.
