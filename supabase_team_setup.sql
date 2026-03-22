-- ============================================================
-- Supabase SQL Setup for Team Members Management
-- Run this in Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Create team_members table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.team_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'office_manager',
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  temp_password TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

-- Owner can do everything with team_members
CREATE POLICY "Owner full access on team_members"
  ON public.team_members FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM auth.users u
      WHERE u.id = auth.uid()
      AND (
        u.raw_user_meta_data->>'role' = 'owner'
        OR u.email IN ('ashok@ambigai.com')
      )
    )
  );

-- Team members can read their own record
CREATE POLICY "Team members can read own record"
  ON public.team_members FOR SELECT
  USING (user_id = auth.uid());


-- 2. RPC: Delete a team user's auth account
-- ============================================================
CREATE OR REPLACE FUNCTION public.delete_team_user(target_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM auth.users WHERE id = target_user_id;
END;
$$;


-- 3. RPC: Update a team user's password
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_team_user_password(
  target_user_id UUID,
  new_password TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE auth.users
  SET encrypted_password = crypt(new_password, gen_salt('bf')),
      updated_at = NOW()
  WHERE id = target_user_id;
END;
$$;


-- 4. Fix: Ensure profiles table INSERT policy allows new users
--    (The handle_new_user trigger needs to be able to insert profiles)
-- ============================================================
-- If you have a handle_new_user trigger, make sure it has SECURITY DEFINER
-- so it bypasses RLS. Run this to re-create it safely:

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'customer')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Recreate the trigger (drop if exists, then create)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();


-- ============================================================
-- IMPORTANT NOTES:
-- ============================================================
-- 
-- 1. The Flutter app now creates team users via signUp() (not RPC).
--    This properly creates entries in both auth.users AND
--    auth.identities, which is required for login to work.
--
-- 2. The delete_team_user and update_team_user_password RPCs
--    are still needed for removing team members and resetting
--    their passwords from the owner's dashboard.
--
-- 3. Make sure "Email Confirmations" are DISABLED in:
--    Supabase Dashboard → Authentication → Settings → Email Auth
--    Otherwise new team members will need to confirm their email
--    before they can log in.
--
-- 4. If you previously created team members that can't login,
--    delete them from Authentication → Users in the Supabase
--    Dashboard, then re-create them through the app.
-- ============================================================
