-- Correct the original Phase 2 grants: order snapshots are visible only to members,
-- while service roles must not bypass the transactional submission API.
REVOKE INSERT, UPDATE, DELETE ON public.orders FROM authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.order_items FROM authenticated;

-- Keep execution explicit for trusted server administration and authenticated staff.
REVOKE ALL ON FUNCTION public.submit_order(uuid, uuid, text, jsonb, text)
  FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.submit_order(uuid, uuid, text, jsonb, text)
  TO authenticated;

-- Use separate trigger events to avoid UPDATE OF combined-event grammar differences.
DROP TRIGGER IF EXISTS dining_sessions_assign_currency ON public.dining_sessions;
CREATE TRIGGER dining_sessions_assign_currency_insert
  BEFORE INSERT ON public.dining_sessions
  FOR EACH ROW EXECUTE FUNCTION private.assign_session_currency();
CREATE TRIGGER dining_sessions_assign_currency_update
  BEFORE UPDATE OF hotel_id ON public.dining_sessions
  FOR EACH ROW EXECUTE FUNCTION private.assign_session_currency();
