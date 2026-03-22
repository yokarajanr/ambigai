-- ============================================================
-- Supabase SQL Setup for Products Table
-- Run this in Supabase Dashboard → SQL Editor
-- 
-- Ambigai Bricks - Product/Brick Management
-- ============================================================

-- 1. Create products table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.products (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  description TEXT,
  price_per_unit DECIMAL(10, 2) NOT NULL DEFAULT 0,
  unit TEXT NOT NULL DEFAULT 'piece',
  is_active BOOLEAN NOT NULL DEFAULT true,
  display_order INTEGER NOT NULL DEFAULT 0,
  color_value BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Enable Row Level Security
-- ============================================================
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- 3. RLS Policies
-- ============================================================

-- Everyone (authenticated) can view active products
CREATE POLICY "Anyone can view active products" 
  ON public.products FOR SELECT 
  USING (is_active = true);

-- Staff can view all products (including inactive)
CREATE POLICY "Staff can view all products" 
  ON public.products FOR SELECT 
  USING (
    auth.jwt() ->> 'email' IN ('ashok@ambigai.com', 'manager@ambigai.com')
    OR auth.jwt() -> 'user_metadata' ->> 'role' IN ('owner', 'office_manager')
  );

-- Owner and Manager can insert/update/delete products
CREATE POLICY "Staff can manage products" 
  ON public.products FOR ALL
  USING (
    auth.jwt() ->> 'email' IN ('ashok@ambigai.com', 'manager@ambigai.com')
    OR auth.jwt() -> 'user_metadata' ->> 'role' IN ('owner', 'office_manager')
  );

-- 4. Auto-update timestamp trigger
-- ============================================================
DROP TRIGGER IF EXISTS update_products_updated_at ON public.products;
CREATE TRIGGER update_products_updated_at
  BEFORE UPDATE ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();

-- 5. Insert default brick products
-- ============================================================
INSERT INTO public.products (name, description, price_per_unit, unit, is_active, display_order, color_value) VALUES
  ('Fly Ash Bricks', 'Lightweight, eco-friendly bricks made from fly ash. Excellent thermal insulation.', 7.00, 'piece', true, 1, 4282549748),
  ('Interlock Bricks', 'Self-locking bricks that require no mortar. Faster construction.', 12.00, 'piece', true, 2, 4294198070),
  ('Paver Bricks', 'Durable paving bricks for driveways, walkways, and outdoor areas.', 15.00, 'piece', true, 3, 4281558835),
  ('Hollow Bricks', 'Lightweight hollow blocks for walls. Good insulation and easy to handle.', 35.00, 'piece', true, 4, 4288585374)
ON CONFLICT (name) DO UPDATE SET
  price_per_unit = EXCLUDED.price_per_unit,
  description = EXCLUDED.description,
  updated_at = NOW();

-- ============================================================
-- VERIFICATION: Check products were created
-- ============================================================
-- SELECT * FROM public.products ORDER BY display_order;

-- ============================================================
-- TO UPDATE PRICES LATER (Example):
-- ============================================================
-- UPDATE public.products SET price_per_unit = 8.00 WHERE name = 'Fly Ash Bricks';
-- UPDATE public.products SET price_per_unit = 14.00 WHERE name = 'Interlock Bricks';

