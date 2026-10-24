-- Run with `supabase test db --local` after `supabase start` and `supabase db reset`.
-- All fixture membership writes (including deferred auth.users FKs) and order
-- submissions are wrapped in this transaction and rolled back at the end.
BEGIN;
SET CONSTRAINTS ALL DEFERRED;
CREATE EXTENSION IF NOT EXISTS pgtap WITH SCHEMA extensions;

INSERT INTO public.hotel_memberships (hotel_id, user_id, role, status)
VALUES
  ('00000000-0000-4000-8000-000000000001', 'f0000000-0000-4000-8000-000000000001', 'owner', 'active'),
  ('00000000-0000-4000-8000-000000000002', 'f0000000-0000-4000-8000-000000000001', 'owner', 'active'),
  ('00000000-0000-4000-8000-000000000002', 'f0000000-0000-4000-8000-000000000002', 'manager', 'active');

SELECT extensions.plan(30);

SELECT extensions.ok(
  (SELECT count(*) = 17 AND count(*) FILTER (WHERE c.relrowsecurity) = 17
   FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
   WHERE n.nspname = 'public' AND c.relkind = 'r'),
  'all 17 application tables have row-level security enabled');

-- RLS checks run as authenticated users with controlled JWT claims, never as owner.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', 'f0000000-0000-4000-8000-000000000001', true);
SELECT set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
SELECT extensions.is((SELECT count(*)::integer FROM public.hotels), 2, 'member sees only hotels where they are a member');
SELECT extensions.is((SELECT count(*)::integer FROM public.menu_items), 4, 'multi-hotel owner sees only their two hotel catalogs');
SELECT extensions.throws_ok(
  $$UPDATE public.menu_items SET hotel_id = '00000000-0000-4000-8000-000000000002', category_id = '00000000-0000-4000-8000-000000000103' WHERE id = '00000000-0000-4000-8000-000000000201'$$,
  '42501', NULL, 'even a multi-hotel owner cannot change a catalog row tenant');

-- A second identity belongs only to hotel B.
SELECT set_config('request.jwt.claim.sub', 'f0000000-0000-4000-8000-000000000002', true);
SELECT set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
SELECT extensions.is((SELECT count(*)::integer FROM public.hotels), 1, 'second member sees one hotel');
SELECT extensions.is((SELECT count(*)::integer FROM public.menu_items), 2, 'second member sees only hotel B menu items');
SELECT extensions.is((SELECT count(*)::integer FROM public.menu_items WHERE hotel_id = '00000000-0000-4000-8000-000000000001'), 0, 'second member cannot read hotel A items');
SELECT extensions.throws_ok(
  $$INSERT INTO public.menu_categories (hotel_id, slug, name_en, name_am) VALUES ('00000000-0000-4000-8000-000000000001', 'unauthorized-test', 'Unauthorized', 'ያልተፈቀደ')$$,
  '42501', NULL, 'second member cannot insert into hotel A');
SELECT extensions.throws_ok(
  $$UPDATE public.menu_items SET hotel_id = '00000000-0000-4000-8000-000000000001' WHERE id = '00000000-0000-4000-8000-000000000203'$$,
  '42501', NULL, 'second member cannot move hotel B item to hotel A');
SELECT extensions.lives_ok(
  $$UPDATE public.menu_items SET name_en = name_en WHERE id = '00000000-0000-4000-8000-000000000203'$$,
  'manager can update an allowed catalog field in their own hotel');
DELETE FROM public.menu_items WHERE id = '00000000-0000-4000-8000-000000000201';
SELECT extensions.ok(NOT has_table_privilege('authenticated', 'public.orders', 'insert'), 'authenticated clients cannot write order rows directly');
SELECT extensions.ok(NOT has_table_privilege('authenticated', 'public.order_items', 'insert'), 'authenticated clients cannot write order item snapshots directly');
SELECT extensions.ok(NOT has_table_privilege('anon', 'public.hotels', 'select'), 'anonymous role has no hotel table grant');
SELECT extensions.ok(NOT has_function_privilege('anon', 'public.submit_order(uuid,uuid,text,jsonb,text)', 'execute'), 'anonymous role cannot submit orders');

-- Valid submission uses trusted DB prices, snapshots, and safe idempotency.
SELECT set_config('request.jwt.claim.sub', 'f0000000-0000-4000-8000-000000000001', true);
SELECT set_config('request.jwt.claims', '{"sub":"f0000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
SELECT extensions.is((SELECT count(*)::integer FROM public.menu_items WHERE id = '00000000-0000-4000-8000-000000000201'), 1, 'hotel A item remains after hotel B member attempted delete');
SELECT extensions.is(
  (SELECT duplicate_submission FROM public.submit_order(
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000701',
    'phase2-test-idempotency-001',
    '[{"menu_item_id":"00000000-0000-4000-8000-000000000201","quantity":2,"modifier_ids":["00000000-0000-4000-8000-000000000401"]}]'::jsonb,
    'pgTAP test'
  )), false, 'first valid order submission creates a new order');
SELECT extensions.is(
  (SELECT total_minor FROM public.orders WHERE idempotency_key = 'phase2-test-idempotency-001'),
  62000::bigint, 'order total comes from the database price and selected modifier');
SELECT extensions.is(
  (SELECT subtotal_minor FROM public.order_items oi JOIN public.orders o ON o.hotel_id = oi.hotel_id AND o.id = oi.order_id WHERE o.idempotency_key = 'phase2-test-idempotency-001'),
  62000::bigint, 'order item stores a price snapshot');
SELECT extensions.is(
  (SELECT duplicate_submission FROM public.submit_order(
    '00000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-000000000701',
    'phase2-test-idempotency-001',
    '[{"menu_item_id":"00000000-0000-4000-8000-000000000201","quantity":2,"modifier_ids":["00000000-0000-4000-8000-000000000401"]}]'::jsonb,
    'pgTAP test'
  )), true, 'identical order retry returns the original order');
SELECT extensions.throws_ok(
  $$SELECT * FROM public.submit_order('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000701','phase2-invalid-quantity','[{"menu_item_id":"00000000-0000-4000-8000-000000000201","quantity":0}]'::jsonb,NULL)$$,
  '22023', NULL, 'zero quantity is rejected');
SELECT extensions.throws_ok(
  $$SELECT * FROM public.submit_order('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000701','phase2-unavailable-item','[{"menu_item_id":"00000000-0000-4000-8000-000000000204","quantity":1}]'::jsonb,NULL)$$,
  '22023', NULL, 'unavailable dish is rejected');
SELECT extensions.throws_ok(
  $$SELECT * FROM public.submit_order('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000703','phase2-closed-session','[{"menu_item_id":"00000000-0000-4000-8000-000000000201","quantity":1}]'::jsonb,NULL)$$,
  '22023', NULL, 'closed dining session is rejected');
SELECT extensions.throws_ok(
  $$SELECT * FROM public.submit_order('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000701','phase2-atomic-rollback','[{"menu_item_id":"00000000-0000-4000-8000-000000000201","quantity":1},{"menu_item_id":"00000000-0000-4000-8000-000000000204","quantity":1}]'::jsonb,NULL)$$,
  '22023', NULL, 'invalid later line rejects the entire order submission');
SELECT extensions.is(
  (SELECT count(*)::integer FROM public.orders WHERE idempotency_key = 'phase2-atomic-rollback'),
  0, 'failed multi-line order leaves no partial order row');
SELECT extensions.throws_ok(
  $$SELECT * FROM public.submit_order('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000701','phase2-test-idempotency-001','[{"menu_item_id":"00000000-0000-4000-8000-000000000201","quantity":3}]'::jsonb,NULL)$$,
  '22023', NULL, 'reusing an idempotency key with a different request is rejected');

-- Constraint tests use the database owner only for integrity checks, not RLS checks.
RESET ROLE;
SELECT extensions.throws_ok(
  $$INSERT INTO public.menu_items (hotel_id, category_id, slug, name_en, name_am, price_minor) VALUES ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000103','cross-hotel-test','Invalid','ስህተት',100)$$,
  '23503', NULL, 'composite foreign key rejects cross-hotel menu category');
SELECT extensions.throws_ok(
  $$INSERT INTO public.restaurant_tables (hotel_id, table_number, label) VALUES ('00000000-0000-4000-8000-000000000001',1,'duplicate table')$$,
  '23505', NULL, 'hotel table number is unique');
SELECT extensions.throws_ok(
  $$INSERT INTO public.payments (hotel_id, dining_session_id, amount_minor, currency, payment_method) VALUES ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000701',-1,'ETB','cash')$$,
  '23514', NULL, 'payment amount must be positive');
SELECT extensions.throws_ok(
  $$INSERT INTO public.payments (hotel_id, dining_session_id, amount_minor, currency, payment_method, external_reference) VALUES ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000701',12000,'ETB','cash','demo-cash-addis-001')$$,
  '23505', NULL, 'payment external reference cannot be duplicated within a hotel');
WITH new_session AS (
  INSERT INTO public.dining_sessions (id, hotel_id, table_id, currency)
  VALUES ('00000000-0000-4000-8000-000000009999','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000602','USD')
  RETURNING currency
)
SELECT extensions.is((SELECT currency FROM new_session), 'ETB'::text, 'session currency is assigned from the active hotel');

RESET ROLE;
DO $assertions$
BEGIN
  IF EXISTS (SELECT 1 FROM public.menu_categories WHERE slug = 'unauthorized-test') THEN
    RAISE EXCEPTION 'cross-hotel insert unexpectedly succeeded';
  END IF;
  IF (SELECT hotel_id FROM public.menu_items WHERE id = '00000000-0000-4000-8000-000000000203')
      IS DISTINCT FROM '00000000-0000-4000-8000-000000000002'::uuid THEN
    RAISE EXCEPTION 'cross-hotel ownership update unexpectedly succeeded';
  END IF;
  IF EXISTS (SELECT 1 FROM public.orders WHERE idempotency_key IN ('phase2-invalid-quantity','phase2-unavailable-item','phase2-closed-session','phase2-atomic-rollback')) THEN
    RAISE EXCEPTION 'a rejected order request left persisted rows: %',
      (SELECT string_agg(idempotency_key, ',') FROM public.orders WHERE idempotency_key IN ('phase2-invalid-quantity','phase2-unavailable-item','phase2-closed-session','phase2-atomic-rollback'));
  END IF;
END;
$assertions$;

SELECT * FROM extensions.finish();
ROLLBACK;
