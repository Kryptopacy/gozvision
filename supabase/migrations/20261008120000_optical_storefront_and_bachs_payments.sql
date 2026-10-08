-- Migration: 20261008120000_optical_storefront_and_bachs_payments.sql
-- Optical Storefront, Dispensary Catalog, Multi-Tenant Orders, and Bachs Payment Accounts.

-- 1. Clinic Payment Accounts (Bachs Merchant / Subaccount Configuration)
create table if not exists public.clinic_payment_accounts (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade unique,
  provider text not null default 'bachs',
  account_id text not null,
  account_status text not null default 'active' check (account_status in ('active', 'pending_verification', 'suspended')),
  settlement_currency text not null default 'USD',
  payout_bank_name text,
  payout_account_mask text,
  auto_payout boolean not null default true,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Optical Dispensary & Storefront Products
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  name text not null,
  sku text,
  category text not null check (category in ('frames', 'lenses', 'smart_glasses', 'assistive_tech', 'therapeutics', 'contact_lenses', 'accessories')),
  description text,
  price numeric(10, 2) not null check (price >= 0),
  currency text not null default 'USD',
  stock_quantity int not null default 0 check (stock_quantity >= 0),
  is_prescription_required boolean not null default false,
  image_url text,
  attributes jsonb default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. Patient Orders & Optical Prescriptions
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references public.clinics (id) on delete cascade,
  patient_id text not null,
  order_number text not null unique,
  status text not null default 'pending' check (status in ('pending', 'paid', 'processing', 'ready_for_pickup', 'shipped', 'delivered', 'cancelled', 'refunded')),
  total_amount numeric(10, 2) not null check (total_amount >= 0),
  currency text not null default 'USD',
  payment_provider text not null default 'bachs',
  payment_reference text,
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid', 'authorized', 'captured', 'failed', 'refunded')),
  fulfillment_type text not null default 'pickup' check (fulfillment_type in ('pickup', 'shipping')),
  shipping_address jsonb,
  prescription_snapshot jsonb,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 4. Order Line Items
create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  product_name text not null,
  quantity int not null default 1 check (quantity > 0),
  unit_price numeric(10, 2) not null check (unit_price >= 0),
  subtotal numeric(10, 2) not null check (subtotal >= 0),
  customizations jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- 5. Performance Indexes
create index if not exists idx_products_clinic_category on public.products (clinic_id, category, is_active);
create index if not exists idx_orders_clinic_status on public.orders (clinic_id, status, created_at desc);
create index if not exists idx_orders_patient on public.orders (patient_id, created_at desc);
create index if not exists idx_order_items_order_id on public.order_items (order_id);

-- 6. Enable Row Level Security
alter table public.clinic_payment_accounts enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

-- 7. RLS Policies: Products
create policy "Staff can manage their clinic products"
  on public.products for all
  using (
    clinic_id = internal.my_clinic_id() and internal.is_staff()
  )
  with check (
    clinic_id = internal.my_clinic_id() and internal.is_staff()
  );

create policy "Patients and public can view active products"
  on public.products for select
  using (
    is_active = true and (
      clinic_id = internal.my_clinic_id() or
      auth.role() in ('authenticated', 'anon')
    )
  );

-- 8. RLS Policies: Orders
create policy "Clinic staff can view and manage clinic orders"
  on public.orders for all
  using (
    clinic_id = internal.my_clinic_id() and internal.is_staff()
  )
  with check (
    clinic_id = internal.my_clinic_id() and internal.is_staff()
  );

create policy "Patients can view their own orders"
  on public.orders for select
  using (
    patient_id = auth.uid()::text or
    patient_id = current_setting('app.current_patient_id', true)
  );

create policy "Patients can create orders for their clinic"
  on public.orders for insert
  with check (
    patient_id = auth.uid()::text or
    patient_id = current_setting('app.current_patient_id', true)
  );

-- 9. RLS Policies: Order Items
create policy "Users can view order items for accessible orders"
  on public.order_items for select
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
      and (
        (o.clinic_id = internal.my_clinic_id() and internal.is_staff()) or
        o.patient_id = auth.uid()::text or
        o.patient_id = current_setting('app.current_patient_id', true)
      )
    )
  );

create policy "Patients and staff can insert order items"
  on public.order_items for insert
  with check (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
      and (
        (o.clinic_id = internal.my_clinic_id() and internal.is_staff()) or
        o.patient_id = auth.uid()::text or
        o.patient_id = current_setting('app.current_patient_id', true)
      )
    )
  );

-- 10. RLS Policies: Clinic Payment Accounts (Bachs)
create policy "Owners and practitioners can manage Bachs payment account"
  on public.clinic_payment_accounts for all
  using (
    clinic_id = internal.my_clinic_id() and internal.is_practitioner()
  )
  with check (
    clinic_id = internal.my_clinic_id() and internal.is_practitioner()
  );

create policy "Staff can view payment account status"
  on public.clinic_payment_accounts for select
  using (
    clinic_id = internal.my_clinic_id() and internal.is_staff()
  );
