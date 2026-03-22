-- ============================================================
-- Supabase SQL Setup for Orders Table
-- Run this in Supabase Dashboard → SQL Editor
-- 
-- Ambigai Bricks - Order & Payment Management System
-- Version: 2.0 (Updated for Phase 1 requirements)
-- ============================================================

-- 1. Create orders table
-- ============================================================
CREATE TABLE IF NOT EXISTS public.orders (
  -- Primary Key
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  
  -- Order Identification
  order_number TEXT UNIQUE,  -- Human-readable: ORD-2026-0001
  
  -- Customer Details (entered by manager for phone orders)
  customer_name TEXT NOT NULL,
  customer_phone TEXT,
  customer_address TEXT,
  
  -- Order Items (stored as JSON array)
  -- Example: [{"brick_type": "Wire Cut", "quantity": 1000, "rate": 8.5, "amount": 8500}]
  items JSONB NOT NULL DEFAULT '[]',
  
  -- Pricing
  total_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
  
  -- Order Status
  -- Values: pending, confirmed, processing, ready, delivered, cancelled
  status TEXT NOT NULL DEFAULT 'pending',
  
  -- Delivery Information
  dc_number TEXT,              -- Delivery Challan number: DC-2026-0542
  delivery_date DATE,          -- When delivered
  
  -- Payment Tracking
  -- Values: unpaid, partial, paid
  payment_status TEXT NOT NULL DEFAULT 'unpaid',
  amount_paid DECIMAL(12, 2) NOT NULL DEFAULT 0,
  payment_date DATE,           -- Last payment received date
  
  -- Additional Info
  notes TEXT,                  -- Special instructions
  
  -- Audit Fields
  created_by UUID REFERENCES auth.users(id),  -- Which manager created this
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add indexes for faster lookups
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON public.orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_customer_phone ON public.orders(customer_phone);
CREATE INDEX IF NOT EXISTS idx_orders_delivery_date ON public.orders(delivery_date);


-- 2. Enable Row Level Security
-- ============================================================
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;


-- 3. RLS Policies (Staff Only for Phase 1)
-- ============================================================

-- Staff (Owner & Managers) can view ALL orders
CREATE POLICY "Staff can view all orders" 
  ON public.orders FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users u
      WHERE u.id = auth.uid() 
      AND (
        u.raw_user_meta_data->>'role' IN ('owner', 'office_manager', 'manufacturing_manager')
        OR u.email IN ('ashok@ambigai.com', 'factory@ambigai.com', 'manager@ambigai.com')
      )
    )
  );

-- Staff can create orders (manager enters phone orders)
CREATE POLICY "Staff can create orders" 
  ON public.orders FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM auth.users u
      WHERE u.id = auth.uid() 
      AND (
        u.raw_user_meta_data->>'role' IN ('owner', 'office_manager')
        OR u.email IN ('ashok@ambigai.com', 'manager@ambigai.com')
      )
    )
  );

-- Staff can update any order (status, DC number, payment)
CREATE POLICY "Staff can update orders" 
  ON public.orders FOR UPDATE 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users u
      WHERE u.id = auth.uid() 
      AND (
        u.raw_user_meta_data->>'role' IN ('owner', 'office_manager', 'manufacturing_manager')
        OR u.email IN ('ashok@ambigai.com', 'factory@ambigai.com', 'manager@ambigai.com')
      )
    )
  );

-- Only owner can delete orders
CREATE POLICY "Owner can delete orders" 
  ON public.orders FOR DELETE 
  USING (
    EXISTS (
      SELECT 1 FROM auth.users u
      WHERE u.id = auth.uid() 
      AND (
        u.raw_user_meta_data->>'role' = 'owner'
        OR u.email = 'ashok@ambigai.com'
      )
    )
  );


-- 4. Function to auto-update the updated_at timestamp
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update timestamp on any row update
DROP TRIGGER IF EXISTS update_orders_updated_at ON public.orders;
CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.update_updated_at_column();


-- 5. Function to auto-generate order number
-- ============================================================
CREATE OR REPLACE FUNCTION public.generate_order_number()
RETURNS TRIGGER AS $$
DECLARE
  year_part TEXT;
  next_seq INTEGER;
BEGIN
  -- Get current year
  year_part := TO_CHAR(NOW(), 'YYYY');
  
  -- Get next sequence number for this year
  SELECT COALESCE(MAX(
    CAST(SUBSTRING(order_number FROM 'ORD-' || year_part || '-(\d+)') AS INTEGER)
  ), 0) + 1
  INTO next_seq
  FROM public.orders
  WHERE order_number LIKE 'ORD-' || year_part || '-%';
  
  -- Generate order number: ORD-2026-0001
  NEW.order_number := 'ORD-' || year_part || '-' || LPAD(next_seq::TEXT, 4, '0');
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-generate order number on insert
DROP TRIGGER IF EXISTS generate_order_number_trigger ON public.orders;
CREATE TRIGGER generate_order_number_trigger
  BEFORE INSERT ON public.orders
  FOR EACH ROW
  WHEN (NEW.order_number IS NULL)
  EXECUTE FUNCTION public.generate_order_number();


-- ============================================================
-- VERIFICATION: Run this to confirm table was created
-- ============================================================
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'orders'
-- ORDER BY ordinal_position;

-- ============================================================
-- TABLE STRUCTURE SUMMARY:
-- ============================================================
-- id              : Unique ID (auto)
-- order_number    : ORD-2026-0001 (auto-generated)
-- customer_name   : Customer name
-- customer_phone  : Phone number
-- customer_address: Delivery address
-- items           : [{brick_type, quantity, rate, amount}]
-- total_amount    : Total bill
-- status          : pending/confirmed/processing/ready/delivered/cancelled
-- dc_number       : Delivery Challan number
-- delivery_date   : When delivered
-- payment_status  : unpaid/partial/paid
-- amount_paid     : How much paid
-- payment_date    : Last payment date
-- notes           : Special instructions
-- created_by      : Which manager created
-- created_at      : When created (auto)
-- updated_at      : Last update (auto)
-- ============================================================

