# Supabase Setup Guide for Ambigai Bricks App

This guide will walk you through setting up Supabase for the Ambigai Bricks application with role-based authentication.

## 📋 Prerequisites

- A Supabase account (sign up at https://supabase.com)
- Your project credentials (URL and Anon Key)

## 🚀 Step 1: Create a Supabase Project

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Click "New Project"
3. Fill in:
   - **Project Name**: `ambigai-bricks` (or your preferred name)
   - **Database Password**: Create a strong password (save it securely)
   - **Region**: Choose closest to your users
4. Click "Create new project"
5. Wait for the project to finish setting up (1-2 minutes)

## 🔐 Step 2: Get Your Supabase Credentials

1. In your project dashboard, click on **Settings** (gear icon) in the sidebar
2. Go to **API** section
3. Copy the following:
   - **Project URL** (looks like `https://xxxxx.supabase.co`)
   - **Anon/Public Key** (long string starting with `eyJ...`)

## 💾 Step 3: Add Credentials to Your App

1. Open `lib/core/config/app_config.dart` in your Flutter project
2. Replace the placeholder values:

```dart
class AppConfig {
  static const String supabaseUrl = 'YOUR_SUPABASE_URL_HERE';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
}
```

**Example:**
```dart
class AppConfig {
  static const String supabaseUrl = 'https://abcdefghijk.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
}
```

## 🗄️ Step 4: Set Up Database Tables

### 4.1 Create Profiles Table

Run this SQL in Supabase SQL Editor (Database → SQL Editor):

```sql
-- Create a table for user profiles
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  full_name TEXT NOT NULL,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'customer',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create policies
-- Users can view their own profile
CREATE POLICY "Users can view own profile" 
  ON public.profiles FOR SELECT 
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" 
  ON public.profiles FOR UPDATE 
  USING (auth.uid() = id);

-- Owner can view all profiles
CREATE POLICY "Owner can view all profiles" 
  ON public.profiles FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'owner'
    )
  );

-- Owner can insert new profiles (for managers)
CREATE POLICY "Owner can insert profiles" 
  ON public.profiles FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'owner'
    )
  );

-- Create function to automatically create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, phone, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'phone', ''),
    COALESCE(NEW.raw_user_meta_data->>'role', 'customer')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile on user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
```

### 4.2 Create Orders Table (for future use)

```sql
-- Create orders table
CREATE TABLE public.orders (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  customer_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
  order_number TEXT UNIQUE NOT NULL,
  brick_type TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  total_amount DECIMAL(10, 2),
  delivery_address TEXT,
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

-- Customers can view their own orders
CREATE POLICY "Customers can view own orders" 
  ON public.orders FOR SELECT 
  USING (customer_id = auth.uid());

-- Customers can create orders
CREATE POLICY "Customers can create orders" 
  ON public.orders FOR INSERT 
  WITH CHECK (customer_id = auth.uid());

-- Staff can view all orders
CREATE POLICY "Staff can view all orders" 
  ON public.orders FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND role IN ('owner', 'office_manager', 'manufacturing_manager')
    )
  );

-- Staff can update orders
CREATE POLICY "Staff can update orders" 
  ON public.orders FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND role IN ('owner', 'office_manager', 'manufacturing_manager')
    )
  );

-- Staff can insert orders (office manager, owner)
CREATE POLICY "Staff can insert orders" 
  ON public.orders FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND role IN ('owner', 'office_manager')
    )
  );

-- Owner and office manager can delete orders
CREATE POLICY "Staff can delete orders" 
  ON public.orders FOR DELETE 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() 
      AND role IN ('owner', 'office_manager')
    )
  );
```

## ✉️ Step 5: Configure Email Authentication

### 5.1 Enable Email Confirmation (Recommended)

1. In Supabase Dashboard, go to **Authentication** → **Settings**
2. Under **Email Auth**, configure:
   - ✅ **Enable Email Confirmations**: ON (for production)
   - 📧 **Confirm email**: ON
   - 🔗 **Secure email change**: ON

### 5.2 Customize Email Templates (Optional)

1. Go to **Authentication** → **Email Templates**
2. Customize the "Confirm Signup" email with your branding

**For Development**: You can disable email confirmation temporarily:
- Turn OFF "Enable Email Confirmations"
- This allows testing without email verification

## 👤 Step 6: Create the Owner Account

### Option A: Through Supabase Dashboard (Recommended)

1. Go to **Authentication** → **Users**
2. Click "Add User" → "Create new user"
3. Fill in:
   - **Email**: owner@ambigaibricks.com (or your email)
   - **Password**: Create a strong password
   - **Auto Confirm User**: ✅ (check this)
4. Click "Create user"
5. After user is created, go to **Database** → **Table Editor** → **profiles**
6. Find the owner's profile row and update:
   - **role**: Change from `customer` to `owner`
   - **full_name**: Update if needed

### Option B: Through SQL

```sql
-- Insert owner user (replace with your email and desired password)
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_user_meta_data,
  created_at,
  updated_at
)
VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'owner@ambigaibricks.com', -- Your email
  crypt('YourStrongPassword123', gen_salt('bf')), -- Your password
  NOW(),
  '{"full_name": "Owner Name", "phone": "+91 12345 67890", "role": "owner"}'::jsonb,
  NOW(),
  NOW()
);
```

## 🔒 Step 7: Security Settings

### 7.1 Configure Site URL (Important for redirects)

1. Go to **Authentication** → **URL Configuration**
2. Add your app URLs:
   - **Site URL**: `http://localhost:3000` (for development)
   - **Redirect URLs**: Add your production domain when ready

### 7.2 Password Requirements

1. Go to **Authentication** → **Settings**
2. Under **Password Requirements**:
   - Minimum length: 6 (or stronger)
   - Consider enabling: Uppercase, lowercase, numbers, special characters

## 🧪 Step 8: Test Your Setup

### Test Customer Signup:
1. Run your Flutter app
2. Go to the signup screen
3. Create a test customer account
4. Check your email for verification link (if enabled)
5. Verify you can login after confirmation

### Test Owner Login:
1. Use the owner credentials you created
2. Login through the app
3. Verify you have access to all features

### Verify Database:
1. Go to Supabase Dashboard → **Table Editor** → **profiles**
2. You should see:
   - Your owner profile with `role = 'owner'`
   - Any test customer profiles with `role = 'customer'`

## 👥 Step 9: Creating Manager Accounts (For Owner)

Managers (Office & Manufacturing) should NOT use the public signup. The owner creates them:

### Via Supabase Dashboard (Easiest):
1. Go to **Authentication** → **Users** → "Add User"
2. Create new user with email and password
3. ✅ Check "Auto Confirm User"
4. After creation, update their profile in **Database** → **profiles**:
   - Change **role** to either:
     - `office_manager` for Office Managers
     - `manufacturing_manager` for Manufacturing Managers

### Via SQL (Batch Creation):
```sql
-- Insert a manager user
INSERT INTO auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_user_meta_data,
  created_at,
  updated_at
)
VALUES (
  '00000000-0000-0000-0000-000000000000',
  gen_random_uuid(),
  'authenticated',
  'authenticated',
  'manager@ambigaibricks.com',
  crypt('ManagerPassword123', gen_salt('bf')),
  NOW(),
  '{"full_name": "Manager Name", "phone": "+91 12345 67890", "role": "office_manager"}'::jsonb,
  NOW(),
  NOW()
);
```

## 📱 Step 10: Configure App Permissions

Update your Row Level Security (RLS) policies as your app grows:

### Common Policy Patterns:

```sql
-- Allow office managers to create orders on behalf of customers
CREATE POLICY "Office managers can create orders" 
  ON public.orders FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'office_manager'
    )
  );

-- Manufacturing managers can update order production status
CREATE POLICY "Manufacturing managers can update production" 
  ON public.orders FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'manufacturing_manager'
    )
  );
```

## 🔄 Step 11: Essential Supabase Features to Explore

### Real-time Subscriptions (for live updates):
```dart
// Example: Listen to order changes
supabase
  .from('orders')
  .stream(primaryKey: ['id'])
  .listen((data) {
    // Handle real-time updates
  });
```

### Storage (for images/documents):
1. Go to **Storage** in dashboard
2. Create buckets for:
   - `order-documents`
   - `profiles` (for avatars)
3. Set up RLS policies for each bucket

## ⚠️ Common Issues & Solutions

### Issue: "Invalid API key"
- **Solution**: Double-check you copied the **anon/public** key, not the service_role key

### Issue: Users can't sign up
- **Solution**: Check email confirmation settings in Authentication → Settings

### Issue: "Row Level Security policy violation"
- **Solution**: Review your RLS policies in the profiles/orders tables

### Issue: Email not sending
- **Solution**: 
  - For development: Disable email confirmation
  - For production: Configure custom SMTP in Settings → Auth → SMTP

## 📊 Monitoring & Logs

- **Database Logs**: Database → Logs
- **Auth Logs**: Authentication → Logs  
- **API Logs**: Settings → API → Logs

## 🎯 Next Steps

1. ✅ Complete all setup steps above
2. 🧪 Test customer signup and login
3. 👤 Create owner account
4. 🏢 Add manager accounts
5. 📱 Start building your app features!

## 🆘 Need Help?

- [Supabase Documentation](https://supabase.com/docs)
- [Supabase Discord Community](https://discord.supabase.com)
- [Flutter Supabase Package Docs](https://pub.dev/packages/supabase_flutter)

---

**Note**: Remember to never commit your Supabase credentials to version control. Consider using environment variables for production.
