-- Migration: 20261008133000_secure_rag_and_optimize_storefront_rls.sql
-- 1. Secure rag_documents with RLS (Resolves lint 0013 rls_disabled_in_public)
-- 2. Optimize products RLS (Resolves lints 0003 auth_rls_initplan & 0006 multiple_permissive_policies)
-- 3. Optimize orders RLS (Resolves lints 0003 auth_rls_initplan & 0006 multiple_permissive_policies)
-- 4. Optimize order_items RLS (Resolves lint 0003 auth_rls_initplan)
-- 5. Optimize clinic_payment_accounts RLS (Resolves lint 0006 multiple_permissive_policies)

-- ============================================================================
-- 1. SECURE RAG_DOCUMENTS
-- ============================================================================
alter table public.rag_documents enable row level security;

drop policy if exists "Anyone can read rag documents" on public.rag_documents;
drop policy if exists "Staff can insert rag documents" on public.rag_documents;
drop policy if exists "Staff can update rag documents" on public.rag_documents;
drop policy if exists "Staff can delete rag documents" on public.rag_documents;

-- Public / Authenticated read-only access to clinical knowledge guidelines
create policy "rag_documents_select"
  on public.rag_documents for select
  using (true);

-- Staff-only management (service_role bypasses RLS automatically)
create policy "rag_documents_insert"
  on public.rag_documents for insert
  with check ((select internal.is_staff()));

create policy "rag_documents_update"
  on public.rag_documents for update
  using ((select internal.is_staff()))
  with check ((select internal.is_staff()));

create policy "rag_documents_delete"
  on public.rag_documents for delete
  using ((select internal.is_staff()));

-- ============================================================================
-- 2. OPTIMIZE PRODUCTS RLS
-- ============================================================================
drop policy if exists "Staff can manage their clinic products" on public.products;
drop policy if exists "Patients and public can view active products" on public.products;
drop policy if exists "products_select" on public.products;
drop policy if exists "products_insert" on public.products;
drop policy if exists "products_update" on public.products;
drop policy if exists "products_delete" on public.products;

-- Single unified SELECT: active products are visible to everyone; inactive only to clinic staff
create policy "products_select"
  on public.products for select
  using (
    is_active = true
    or (
      clinic_id = (select internal.my_clinic_id())
      and (select internal.is_staff())
    )
  );

create policy "products_insert"
  on public.products for insert
  with check (
    clinic_id = (select internal.my_clinic_id())
    and (select internal.is_staff())
  );

create policy "products_update"
  on public.products for update
  using (
    clinic_id = (select internal.my_clinic_id())
    and (select internal.is_staff())
  )
  with check (
    clinic_id = (select internal.my_clinic_id())
    and (select internal.is_staff())
  );

create policy "products_delete"
  on public.products for delete
  using (
    clinic_id = (select internal.my_clinic_id())
    and (select internal.is_staff())
  );

-- ============================================================================
-- 3. OPTIMIZE ORDERS RLS
-- ============================================================================
drop policy if exists "Clinic staff can view and manage clinic orders" on public.orders;
drop policy if exists "Patients can view their own orders" on public.orders;
drop policy if exists "Patients can create orders for their clinic" on public.orders;
drop policy if exists "orders_select" on public.orders;
drop policy if exists "orders_insert" on public.orders;
drop policy if exists "orders_update" on public.orders;
drop policy if exists "orders_delete" on public.orders;

-- Single unified SELECT: patients view their orders, staff views clinic orders
create policy "orders_select"
  on public.orders for select
  using (
    patient_id = (select auth.uid())::text
    or patient_id = (select nullif(current_setting('app.current_patient_id', true), ''))
    or (
      clinic_id = (select internal.my_clinic_id())
      and (select internal.is_staff())
    )
  );

-- Single unified INSERT: patients or staff can create orders
create policy "orders_insert"
  on public.orders for insert
  with check (
    patient_id = (select auth.uid())::text
    or patient_id = (select nullif(current_setting('app.current_patient_id', true), ''))
    or (
      clinic_id = (select internal.my_clinic_id())
      and (select internal.is_staff())
    )
  );

create policy "orders_update"
  on public.orders for update
  using (
    clinic_id = (select internal.my_clinic_id())
    and (select internal.is_staff())
  )
  with check (
    clinic_id = (select internal.my_clinic_id())
    and (select internal.is_staff())
  );

create policy "orders_delete"
  on public.orders for delete
  using (
    clinic_id = (select internal.my_clinic_id())
    and (select internal.is_staff())
  );

-- ============================================================================
-- 4. OPTIMIZE ORDER ITEMS RLS
-- ============================================================================
drop policy if exists "Users can view order items for accessible orders" on public.order_items;
drop policy if exists "Patients and staff can insert order items" on public.order_items;
drop policy if exists "order_items_select" on public.order_items;
drop policy if exists "order_items_insert" on public.order_items;
drop policy if exists "order_items_update" on public.order_items;
drop policy if exists "order_items_delete" on public.order_items;

create policy "order_items_select"
  on public.order_items for select
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
      and (
        (o.clinic_id = (select internal.my_clinic_id()) and (select internal.is_staff()))
        or o.patient_id = (select auth.uid())::text
        or o.patient_id = (select nullif(current_setting('app.current_patient_id', true), ''))
      )
    )
  );

create policy "order_items_insert"
  on public.order_items for insert
  with check (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
      and (
        (o.clinic_id = (select internal.my_clinic_id()) and (select internal.is_staff()))
        or o.patient_id = (select auth.uid())::text
        or o.patient_id = (select nullif(current_setting('app.current_patient_id', true), ''))
      )
    )
  );

create policy "order_items_update"
  on public.order_items for update
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
      and o.clinic_id = (select internal.my_clinic_id())
      and (select internal.is_staff())
    )
  )
  with check (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
      and o.clinic_id = (select internal.my_clinic_id())
      and (select internal.is_staff())
    )
  );

create policy "order_items_delete"
  on public.order_items for delete
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
      and o.clinic_id = (select internal.my_clinic_id())
      and (select internal.is_staff())
    )
  );

-- ============================================================================
-- 5. OPTIMIZE CLINIC PAYMENT ACCOUNTS RLS
-- ============================================================================
drop policy if exists "Owners and practitioners can manage Bachs payment account" on public.clinic_payment_accounts;
drop policy if exists "Staff can view payment account status" on public.clinic_payment_accounts;
drop policy if exists "clinic_payment_accounts_select" on public.clinic_payment_accounts;
drop policy if exists "clinic_payment_accounts_insert" on public.clinic_payment_accounts;
drop policy if exists "clinic_payment_accounts_update" on public.clinic_payment_accounts;
drop policy if exists "clinic_payment_accounts_delete" on public.clinic_payment_accounts;

-- Single unified SELECT: staff can view their clinic's payment account status
create policy "clinic_payment_accounts_select"
  on public.clinic_payment_accounts for select
  using (
    clinic_id = (select internal.my_clinic_id())
    and (select internal.is_staff())
  );

-- Practitioners/Owners can create, update, delete payment configuration
create policy "clinic_payment_accounts_insert"
  on public.clinic_payment_accounts for insert
  with check (
    clinic_id = (select internal.my_clinic_id())
    and (select internal.is_practitioner())
  );

create policy "clinic_payment_accounts_update"
  on public.clinic_payment_accounts for update
  using (
    clinic_id = (select internal.my_clinic_id())
    and (select internal.is_practitioner())
  )
  with check (
    clinic_id = (select internal.my_clinic_id())
    and (select internal.is_practitioner())
  );

create policy "clinic_payment_accounts_delete"
  on public.clinic_payment_accounts for delete
  using (
    clinic_id = (select internal.my_clinic_id())
    and (select internal.is_practitioner())
  );
