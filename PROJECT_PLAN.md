# Ambigai Bricks App - Project Plan & Progress Tracker

> **IMPORTANT**: When starting a new chat, share this file with the AI to continue from where you left off.

---

## 📋 Project Overview

**App Name:** Ambigai Bricks  
**Purpose:** Digital order & payment management system (replacing physical logbook)  
**Platform:** Flutter (Android, iOS, Web)  
**Backend:** Supabase (PostgreSQL + Auth)

---

## 🎯 Business Requirements

### Primary Goal
Convert manual logbook-based order and payment tracking to a digital app for:
- Order intake management
- Delivery tracking with DC numbers
- Payment status tracking
- Month-wise pending payment reports

### User Roles

| Role | Access Level | Main Tasks |
|------|-------------|------------|
| **Owner** | Full access | View all orders, payments, reports, approve app orders |
| **Office Manager** | Order management | Enter phone orders, update delivery status, track payments |
| **Manufacturing Manager** | Production view | View orders for production planning |
| **Customer** (Phase 2) | Limited | Place orders via app (needs owner approval) |

---

## 🔄 Order Flow (How It Works)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           ORDER LIFECYCLE                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  PHASE 1: Manager Entry (Current Focus)                                 │
│  ───────────────────────────────────────                                │
│                                                                         │
│  Customer Calls ──► Manager Enters Order ──► Order Created              │
│                            │                                            │
│                            ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ ORDER STATUS FLOW:                                              │    │
│  │                                                                 │    │
│  │ [pending] ──► [confirmed] ──► [processing] ──► [delivered]     │    │
│  │                                                    │            │    │
│  │                                          DC Number Added        │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                            │                                            │
│                            ▼                                            │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │ PAYMENT STATUS FLOW:                                            │    │
│  │                                                                 │    │
│  │ [unpaid] ──► [partial] ──► [paid]                              │    │
│  │                                                                 │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│                                                                         │
│  PHASE 2: Customer App Orders (Future)                                  │
│  ──────────────────────────────────────                                 │
│                                                                         │
│  Customer Orders via App ──► [pending_approval] ──► Owner Approves      │
│                                                          │              │
│                                                          ▼              │
│                                              Joins same order flow      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Data Model

### Orders Table Fields

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `id` | UUID | Unique order ID | auto-generated |
| `order_number` | TEXT | Human-readable order # | `ORD-2026-0001` |
| `customer_name` | TEXT | Customer name | `"Ravi Kumar"` |
| `customer_phone` | TEXT | Phone number | `"+91 98765 43210"` |
| `customer_address` | TEXT | Delivery address | `"123 Main St, Chennai"` |
| `items` | JSONB | Ordered items | `[{brick_type, qty, rate}]` |
| `total_amount` | DECIMAL | Total bill amount | `45000.00` |
| `status` | TEXT | Order status | `pending/confirmed/processing/delivered` |
| `dc_number` | TEXT | Delivery Challan # | `"DC-2026-0542"` |
| `delivery_date` | DATE | When delivered | `2026-02-22` |
| `payment_status` | TEXT | Payment state | `unpaid/partial/paid` |
| `amount_paid` | DECIMAL | Amount received | `20000.00` |
| `payment_date` | DATE | Last payment date | `2026-02-25` |
| `notes` | TEXT | Special instructions | `"Call before delivery"` |
| `created_by` | UUID | Who created (manager) | Links to user |
| `created_at` | TIMESTAMP | When created | auto |
| `updated_at` | TIMESTAMP | Last updated | auto |

### Brick Types (Products)

| Brick Type | Price per Unit | Unit |
|------------|---------------|------|
| Wire Cut Bricks | ₹8.50 | piece |
| Table Mould Bricks | ₹7.00 | piece |
| Solid Blocks | ₹45.00 | piece |
| Hollow Blocks | ₹35.00 | piece |
| Fly Ash Bricks | ₹6.50 | piece |
| Fire Bricks | ₹25.00 | piece |

---

## 🗂️ Development Phases

### Phase 1: Core Order & Payment System ⬅️ CURRENT
- [x] Project setup (Flutter + Supabase)
- [x] Authentication system (login/roles)
- [x] Basic UI structure
- [x] **Orders table in Supabase** ✅ DONE
- [ ] Update Flutter OrderService for new table ⬅️ NEXT
- [ ] Manager: Create new order form
- [ ] Manager: View all orders list
- [ ] Manager: Update order status
- [ ] Manager: Add DC number on delivery
- [ ] Manager: Update payment status
- [ ] Owner: Dashboard with order stats
- [ ] Owner: View all orders
- [ ] Owner: Month-wise pending payments report

### Phase 2: Enhanced Features
- [ ] Order search & filters
- [ ] Export reports (PDF/Excel)
- [ ] Print DC/Invoice
- [ ] Order history per customer

### Phase 3: Customer App (Future)
- [ ] Customer registration (with approval)
- [ ] Customer places order via app
- [ ] Owner approves customer orders
- [ ] Customer views their order status

---

## 🗄️ Supabase Tables Status

### Tables Created

| Table | Status | Created On | Notes |
|-------|--------|------------|-------|
| `profiles` | ✅ Created | Earlier | User profiles with roles |
| `team_members` | ✅ Created | Earlier | For owner to manage staff |
| `orders` | ✅ Created | Feb 22, 2026 | Order & payment tracking |

### Tables Pending

| Table | Priority | Purpose |
|-------|----------|---------|
| `customers` | LOW | Customer database (Phase 2) |

---

## 📝 Session Tracking

> **Session details are now tracked in:** [CHAT_LOG.md](CHAT_LOG.md)
> 
> When starting a new chat, share **CHAT_LOG.md** for continuity.

---

## 🔑 Supabase Credentials

**Project URL:** `https://zcfoeralaoubjpxkyrry.supabase.co`  
**Status:** ✅ Connected  
**Location:** `lib/core/config/app_config.dart`

---

## 📁 Key Files Reference

| File | Purpose |
|------|---------|
| `lib/core/services/order_service.dart` | Order CRUD operations |
| `lib/core/services/auth_service.dart` | Authentication & roles |
| `lib/core/services/cart_service.dart` | Shopping cart (for customer app) |
| `lib/features/owner/screens/owner_orders.dart` | Owner's order view |
| `lib/features/manager/screens/` | Manager screens |
| `supabase_orders_setup.sql` | Orders table SQL |
| `supabase_team_setup.sql` | Team members SQL |

---

## 🚀 How to Continue in New Chat

1. **Share this file** (`CHAT_LOG.md`) with the AI
2. **Tell the AI:** "Continue from CHAT_LOG.md"
3. **Check the "Next Tasks"** section in CHAT_LOG.md
4. **AI will pick up from the next step**

---

## ⚠️ Important Notes

- Always run SQL in Supabase Dashboard → SQL Editor
- Test changes on development before production
- Keep CHAT_LOG.md updated after each session
- Backup Supabase data before major table changes

---

*Last Updated: February 22, 2026*
