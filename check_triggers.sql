-- ============================================
-- CHECK TRIGGERS ON AUTH.USERS
-- ============================================

SELECT 
    trigger_name, 
    event_manipulation, 
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
AND event_object_table = 'users';

-- Also check profiles triggers just in case
SELECT 
    trigger_name, 
    event_manipulation
FROM information_schema.triggers
WHERE event_object_schema = 'public'
AND event_object_table = 'profiles';
