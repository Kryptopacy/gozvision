-- Migration: 20261008135000_fix_orders_initplan_performance.sql
-- Optimizes RLS policies on public.orders and public.order_items to eliminate
-- per-row re-evaluation of auth.uid() and remove redundant current_setting calls (Lint 0003 auth_rls_initplan).

-- ============================================================================
-- 1. ORDERS RLS OPTIMIZATION
-- ============================================================================
drop policy if exists "orders_select" on public.orders;
drop policy if exists "orders_insert" on public.orders;

create policy "orders_select"
  on public.orders for select
  using (
    patient_id = (select auth.uid()::text)
    or (
      clinic_id = (select internal.my_clinic_id())
      and (select internal.is_staff())
    )
  );

create policy "orders_insert"
  on public.orders for insert
  with check (
    patient_id = (select auth.uid()::text)
    or (
      clinic_id = (select internal.my_clinic_id())
      and (select internal.is_staff())
    )
  );

-- ============================================================================
-- 2. ORDER ITEMS RLS OPTIMIZATION
-- ============================================================================
-- Rather than redundantly invoking auth.<function> or current_setting per item,
-- access is cleanly delegated to the parent order (which already enforces strict RLS).
drop policy if exists "order_items_select" on public.order_items;
drop policy if exists "order_items_insert" on public.order_items;

create policy "order_items_select"
  on public.order_items for select
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
    )
  );

create policy "order_items_insert"
  on public.order_items for insert
  with check (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id
    )
  );
