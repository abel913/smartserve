-- SmartServe Phase 2: normalized hotel data, tenant constraints, RLS, and safe order creation.
-- This migration only creates new application objects and synthetic development fixtures.

CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO authenticated;

CREATE TABLE public.hotels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 160),
  slug text NOT NULL UNIQUE CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  description text,
  contact_email text,
  contact_phone text,
  website_url text,
  logo_path text,
  branding jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(branding) = 'object'),
  currency text NOT NULL DEFAULT 'ETB' CHECK (currency ~ '^[A-Z]{3}$'),
  timezone text NOT NULL DEFAULT 'Africa/Addis_Ababa',
  operating_settings jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(operating_settings) = 'object'),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'suspended', 'archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (id, currency)
);

CREATE TABLE public.hotel_memberships (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
  role text NOT NULL CHECK (role IN ('owner', 'manager', 'staff', 'kitchen', 'billing')),
  status text NOT NULL DEFAULT 'invited' CHECK (status IN ('invited', 'active', 'suspended', 'revoked')),
  invited_email text,
  invited_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  invited_at timestamptz,
  accepted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hotel_id, user_id),
  UNIQUE (hotel_id, id)
);

-- Platform support access is separate from hotel membership. No API grants or policies are added.
CREATE TABLE public.platform_admins (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  platform_role text NOT NULL CHECK (platform_role IN ('super_admin', 'support_admin')),
  assigned_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.menu_categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  slug text NOT NULL CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_en text NOT NULL CHECK (length(btrim(name_en)) BETWEEN 1 AND 120),
  name_am text NOT NULL CHECK (length(btrim(name_am)) BETWEEN 1 AND 120),
  description_en text,
  description_am text,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  is_published boolean NOT NULL DEFAULT false,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hotel_id, slug),
  UNIQUE (hotel_id, id)
);

CREATE TABLE public.menu_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  category_id uuid NOT NULL,
  slug text NOT NULL CHECK (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  name_en text NOT NULL CHECK (length(btrim(name_en)) BETWEEN 1 AND 160),
  name_am text NOT NULL CHECK (length(btrim(name_am)) BETWEEN 1 AND 160),
  description_en text,
  description_am text,
  price_minor bigint NOT NULL CHECK (price_minor BETWEEN 0 AND 1000000000000),
  image_path text,
  preparation_minutes smallint CHECK (preparation_minutes BETWEEN 0 AND 1440),
  is_available boolean NOT NULL DEFAULT true,
  is_published boolean NOT NULL DEFAULT false,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hotel_id, slug),
  UNIQUE (hotel_id, id),
  CONSTRAINT menu_items_category_same_hotel_fk
    FOREIGN KEY (hotel_id, category_id)
    REFERENCES public.menu_categories(hotel_id, id) ON DELETE RESTRICT
);

CREATE TABLE public.menu_modifier_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  menu_item_id uuid NOT NULL,
  name_en text NOT NULL CHECK (length(btrim(name_en)) BETWEEN 1 AND 120),
  name_am text NOT NULL CHECK (length(btrim(name_am)) BETWEEN 1 AND 120),
  min_selections smallint NOT NULL DEFAULT 0 CHECK (min_selections BETWEEN 0 AND 20),
  max_selections smallint NOT NULL DEFAULT 1 CHECK (max_selections BETWEEN 0 AND 20),
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (min_selections <= max_selections),
  UNIQUE (hotel_id, menu_item_id, id),
  CONSTRAINT modifier_groups_item_same_hotel_fk
    FOREIGN KEY (hotel_id, menu_item_id)
    REFERENCES public.menu_items(hotel_id, id) ON DELETE RESTRICT
);

CREATE TABLE public.menu_item_modifiers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  menu_item_id uuid NOT NULL,
  group_id uuid NOT NULL,
  name_en text NOT NULL CHECK (length(btrim(name_en)) BETWEEN 1 AND 120),
  name_am text NOT NULL CHECK (length(btrim(name_am)) BETWEEN 1 AND 120),
  price_adjustment_minor bigint NOT NULL DEFAULT 0 CHECK (price_adjustment_minor BETWEEN -100000000000 AND 100000000000),
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  archived_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hotel_id, group_id, name_en),
  UNIQUE (hotel_id, menu_item_id, id),
  CONSTRAINT modifiers_group_same_hotel_item_fk
    FOREIGN KEY (hotel_id, menu_item_id, group_id)
    REFERENCES public.menu_modifier_groups(hotel_id, menu_item_id, id) ON DELETE RESTRICT
);

-- This is a global, controlled vocabulary. Dish-specific claims are separately recorded as verified.
CREATE TABLE public.dietary_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE CHECK (code ~ '^[a-z][a-z0-9_]*$'),
  name_en text NOT NULL CHECK (length(btrim(name_en)) BETWEEN 1 AND 80),
  name_am text NOT NULL CHECK (length(btrim(name_am)) BETWEEN 1 AND 80),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.menu_item_dietary_tags (
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  menu_item_id uuid NOT NULL,
  dietary_tag_id uuid NOT NULL REFERENCES public.dietary_tags(id) ON DELETE RESTRICT,
  verified_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  verified_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (hotel_id, menu_item_id, dietary_tag_id),
  CONSTRAINT menu_item_dietary_tags_item_same_hotel_fk
    FOREIGN KEY (hotel_id, menu_item_id)
    REFERENCES public.menu_items(hotel_id, id) ON DELETE RESTRICT
);

CREATE TABLE public.restaurant_tables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  table_number integer NOT NULL CHECK (table_number > 0),
  label text,
  qr_identifier uuid NOT NULL DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hotel_id, table_number),
  UNIQUE (hotel_id, qr_identifier),
  UNIQUE (hotel_id, id)
);

CREATE TABLE public.dining_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  table_id uuid NOT NULL,
  currency text NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed', 'cancelled')),
  settlement_state text NOT NULL DEFAULT 'unsettled' CHECK (settlement_state IN ('unsettled', 'partial', 'settled')),
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((status = 'open' AND closed_at IS NULL) OR (status <> 'open' AND closed_at IS NOT NULL)),
  UNIQUE (hotel_id, id),
  UNIQUE (hotel_id, id, currency),
  CONSTRAINT dining_sessions_table_same_hotel_fk
    FOREIGN KEY (hotel_id, table_id)
    REFERENCES public.restaurant_tables(hotel_id, id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX dining_sessions_one_open_per_table_idx
  ON public.dining_sessions(hotel_id, table_id)
  WHERE status = 'open';

-- QR identifiers only locate a table. Rotating guest credentials are hashed and kept outside API schemas.
CREATE TABLE private.guest_session_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL,
  dining_session_id uuid NOT NULL,
  credential_hash bytea NOT NULL UNIQUE CHECK (octet_length(credential_hash) = 32),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT guest_credentials_session_same_hotel_fk
    FOREIGN KEY (hotel_id, dining_session_id)
    REFERENCES public.dining_sessions(hotel_id, id) ON DELETE CASCADE
);

CREATE TABLE public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  dining_session_id uuid NOT NULL,
  order_number bigint GENERATED ALWAYS AS IDENTITY,
  currency text NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'accepted', 'preparing', 'ready', 'served', 'cancelled')),
  notes text CHECK (notes IS NULL OR length(notes) <= 2000),
  idempotency_key text NOT NULL CHECK (length(btrim(idempotency_key)) BETWEEN 1 AND 128),
  request_hash text NOT NULL CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  total_minor bigint NOT NULL DEFAULT 0 CHECK (total_minor BETWEEN 0 AND 100000000000000000),
  submitted_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hotel_id, order_number),
  UNIQUE (hotel_id, id),
  UNIQUE (hotel_id, id, dining_session_id),
  UNIQUE (hotel_id, idempotency_key),
  CONSTRAINT orders_session_same_hotel_currency_fk
    FOREIGN KEY (hotel_id, dining_session_id, currency)
    REFERENCES public.dining_sessions(hotel_id, id, currency) ON DELETE RESTRICT
);

CREATE TABLE public.order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  order_id uuid NOT NULL,
  menu_item_id uuid NOT NULL,
  quantity smallint NOT NULL CHECK (quantity BETWEEN 1 AND 99),
  item_name_en text NOT NULL,
  item_name_am text NOT NULL,
  item_description_en text,
  item_description_am text,
  unit_price_minor bigint NOT NULL CHECK (unit_price_minor BETWEEN 0 AND 1000000000000),
  modifier_total_minor bigint NOT NULL,
  modifier_snapshot jsonb NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(modifier_snapshot) = 'array'),
  subtotal_minor bigint NOT NULL CHECK (subtotal_minor >= 0),
  status text NOT NULL DEFAULT 'submitted' CHECK (status IN ('submitted', 'accepted', 'preparing', 'ready', 'served', 'cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (unit_price_minor + modifier_total_minor >= 0),
  CHECK (subtotal_minor = quantity::bigint * (unit_price_minor + modifier_total_minor)),
  UNIQUE (hotel_id, id),
  CONSTRAINT order_items_order_same_hotel_fk
    FOREIGN KEY (hotel_id, order_id)
    REFERENCES public.orders(hotel_id, id) ON DELETE RESTRICT,
  CONSTRAINT order_items_menu_item_same_hotel_fk
    FOREIGN KEY (hotel_id, menu_item_id)
    REFERENCES public.menu_items(hotel_id, id) ON DELETE RESTRICT
);

CREATE TABLE public.service_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  dining_session_id uuid NOT NULL,
  request_type text NOT NULL CHECK (request_type IN ('call_waiter', 'request_bill')),
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'acknowledged', 'resolved', 'cancelled')),
  notes text CHECK (notes IS NULL OR length(notes) <= 2000),
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((status IN ('resolved', 'cancelled') AND resolved_at IS NOT NULL) OR (status IN ('open', 'acknowledged') AND resolved_at IS NULL)),
  UNIQUE (hotel_id, id),
  CONSTRAINT service_requests_session_same_hotel_fk
    FOREIGN KEY (hotel_id, dining_session_id)
    REFERENCES public.dining_sessions(hotel_id, id) ON DELETE RESTRICT
);

CREATE TABLE public.payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  dining_session_id uuid NOT NULL,
  amount_minor bigint NOT NULL CHECK (amount_minor BETWEEN 1 AND 1000000000000000),
  currency text NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  payment_method text NOT NULL CHECK (payment_method IN ('cash', 'card', 'mobile_money', 'bank_transfer', 'other')),
  status text NOT NULL DEFAULT 'recorded' CHECK (status IN ('pending', 'recorded', 'failed', 'refunded')),
  external_reference text,
  recorded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hotel_id, id),
  CONSTRAINT payments_session_same_hotel_currency_fk
    FOREIGN KEY (hotel_id, dining_session_id, currency)
    REFERENCES public.dining_sessions(hotel_id, id, currency) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX payments_external_reference_per_hotel_idx
  ON public.payments(hotel_id, external_reference)
  WHERE external_reference IS NOT NULL;

CREATE TABLE public.feedback (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid NOT NULL REFERENCES public.hotels(id) ON DELETE RESTRICT,
  dining_session_id uuid NOT NULL,
  order_id uuid,
  rating smallint NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comments text CHECK (comments IS NULL OR length(comments) <= 4000),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hotel_id, id),
  CONSTRAINT feedback_session_same_hotel_fk
    FOREIGN KEY (hotel_id, dining_session_id)
    REFERENCES public.dining_sessions(hotel_id, id) ON DELETE RESTRICT,
  CONSTRAINT feedback_order_same_hotel_fk
    FOREIGN KEY (hotel_id, order_id, dining_session_id)
    REFERENCES public.orders(hotel_id, id, dining_session_id) ON DELETE RESTRICT
);

CREATE TABLE public.audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  hotel_id uuid REFERENCES public.hotels(id) ON DELETE RESTRICT,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL CHECK (length(btrim(action)) BETWEEN 1 AND 120),
  entity_type text NOT NULL CHECK (length(btrim(entity_type)) BETWEEN 1 AND 120),
  entity_id uuid,
  occurred_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX hotel_memberships_user_status_idx ON public.hotel_memberships(user_id, status, hotel_id);
CREATE INDEX menu_categories_hotel_sort_idx ON public.menu_categories(hotel_id, sort_order, id) WHERE archived_at IS NULL;
CREATE INDEX menu_items_hotel_category_idx ON public.menu_items(hotel_id, category_id, id) WHERE archived_at IS NULL;
CREATE INDEX menu_items_hotel_available_idx ON public.menu_items(hotel_id, is_available, id) WHERE archived_at IS NULL AND is_published;
CREATE INDEX menu_modifier_groups_item_idx ON public.menu_modifier_groups(hotel_id, menu_item_id, sort_order) WHERE archived_at IS NULL;
CREATE INDEX menu_item_modifiers_group_idx ON public.menu_item_modifiers(hotel_id, group_id, sort_order) WHERE archived_at IS NULL;
CREATE INDEX menu_item_dietary_tags_tag_idx ON public.menu_item_dietary_tags(dietary_tag_id, hotel_id, menu_item_id);
CREATE INDEX dining_sessions_hotel_opened_idx ON public.dining_sessions(hotel_id, opened_at DESC);
CREATE INDEX orders_hotel_session_submitted_idx ON public.orders(hotel_id, dining_session_id, submitted_at DESC);
CREATE INDEX order_items_hotel_order_idx ON public.order_items(hotel_id, order_id, id);
CREATE INDEX service_requests_hotel_status_created_idx ON public.service_requests(hotel_id, status, created_at DESC);
CREATE INDEX payments_hotel_session_created_idx ON public.payments(hotel_id, dining_session_id, created_at DESC);
CREATE INDEX feedback_hotel_created_idx ON public.feedback(hotel_id, created_at DESC);
CREATE INDEX audit_events_hotel_time_idx ON public.audit_events(hotel_id, occurred_at DESC) WHERE hotel_id IS NOT NULL;

CREATE OR REPLACE FUNCTION private.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
BEGIN
  NEW.updated_at := pg_catalog.now();
  RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION private.has_hotel_role(p_hotel_id uuid, p_roles text[] DEFAULT NULL)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.hotel_memberships AS hm
    WHERE hm.hotel_id = p_hotel_id
      AND hm.user_id = (SELECT auth.uid())
      AND hm.status = 'active'
      AND (p_roles IS NULL OR hm.role = ANY (p_roles))
  );
$function$;

CREATE OR REPLACE FUNCTION private.assign_session_currency()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
BEGIN
  SELECT h.currency INTO NEW.currency
    FROM public.hotels AS h
    WHERE h.id = NEW.hotel_id AND h.status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active hotel required to open a dining session' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.touch_updated_at() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.touch_updated_at() TO authenticated;
REVOKE ALL ON FUNCTION private.has_hotel_role(uuid, text[]) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.has_hotel_role(uuid, text[]) TO authenticated;
REVOKE ALL ON FUNCTION private.assign_session_currency() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION private.assign_session_currency() TO authenticated;

CREATE TRIGGER hotels_touch_updated_at BEFORE UPDATE ON public.hotels FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
CREATE TRIGGER hotel_memberships_touch_updated_at BEFORE UPDATE ON public.hotel_memberships FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
CREATE TRIGGER menu_categories_touch_updated_at BEFORE UPDATE ON public.menu_categories FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
CREATE TRIGGER menu_items_touch_updated_at BEFORE UPDATE ON public.menu_items FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
CREATE TRIGGER menu_modifier_groups_touch_updated_at BEFORE UPDATE ON public.menu_modifier_groups FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
CREATE TRIGGER menu_item_modifiers_touch_updated_at BEFORE UPDATE ON public.menu_item_modifiers FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
CREATE TRIGGER restaurant_tables_touch_updated_at BEFORE UPDATE ON public.restaurant_tables FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
CREATE TRIGGER dining_sessions_touch_updated_at BEFORE UPDATE ON public.dining_sessions FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
CREATE TRIGGER dining_sessions_assign_currency BEFORE INSERT OR UPDATE OF hotel_id ON public.dining_sessions FOR EACH ROW EXECUTE FUNCTION private.assign_session_currency();
CREATE TRIGGER orders_touch_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
CREATE TRIGGER service_requests_touch_updated_at BEFORE UPDATE ON public.service_requests FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();
CREATE TRIGGER payments_touch_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION private.touch_updated_at();

ALTER TABLE public.hotels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hotel_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.platform_admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_modifier_groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_item_modifiers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dietary_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.menu_item_dietary_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.restaurant_tables ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dining_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE private.guest_session_credentials ENABLE ROW LEVEL SECURITY;

GRANT USAGE ON SCHEMA public TO authenticated;

REVOKE ALL ON TABLE public.hotels, public.hotel_memberships, public.platform_admins,
  public.menu_categories, public.menu_items, public.menu_modifier_groups, public.menu_item_modifiers,
  public.dietary_tags, public.menu_item_dietary_tags, public.restaurant_tables, public.dining_sessions,
  public.orders, public.order_items, public.service_requests, public.payments, public.feedback,
  public.audit_events FROM PUBLIC, anon;

GRANT SELECT ON public.hotels TO authenticated;
GRANT UPDATE (name, description, slug, contact_email, contact_phone, website_url, logo_path, branding, timezone, operating_settings, status)
  ON public.hotels TO authenticated;
GRANT SELECT ON public.hotel_memberships TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.menu_categories, public.menu_items,
  public.menu_modifier_groups, public.menu_item_modifiers, public.menu_item_dietary_tags,
  public.restaurant_tables TO authenticated;
GRANT SELECT ON public.dietary_tags TO authenticated;
GRANT SELECT ON public.dining_sessions TO authenticated;
GRANT INSERT (hotel_id, table_id) ON public.dining_sessions TO authenticated;
GRANT UPDATE (status, settlement_state, closed_at) ON public.dining_sessions TO authenticated;
GRANT SELECT (id, hotel_id, dining_session_id, order_number, currency, status, notes, total_minor, submitted_at, created_at, updated_at)
  ON public.orders TO authenticated;
GRANT SELECT ON public.order_items, public.feedback, public.audit_events TO authenticated;
GRANT SELECT ON public.payments TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.service_requests TO authenticated;
REVOKE ALL ON TABLE private.guest_session_credentials FROM PUBLIC, anon, authenticated, service_role;

CREATE POLICY hotels_member_select ON public.hotels
  FOR SELECT TO authenticated USING (private.has_hotel_role(id));
CREATE POLICY hotels_manager_update ON public.hotels
  FOR UPDATE TO authenticated USING (private.has_hotel_role(id, ARRAY['owner', 'manager']))
  WITH CHECK (private.has_hotel_role(id, ARRAY['owner', 'manager']));

CREATE POLICY memberships_self_or_manager_select ON public.hotel_memberships
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) OR private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));

CREATE POLICY categories_member_select ON public.menu_categories
  FOR SELECT TO authenticated USING (private.has_hotel_role(hotel_id));
CREATE POLICY categories_manager_insert ON public.menu_categories
  FOR INSERT TO authenticated WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));
CREATE POLICY categories_manager_update ON public.menu_categories
  FOR UPDATE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']))
  WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));
CREATE POLICY categories_manager_delete ON public.menu_categories
  FOR DELETE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));

CREATE POLICY menu_items_member_select ON public.menu_items
  FOR SELECT TO authenticated USING (private.has_hotel_role(hotel_id));
CREATE POLICY menu_items_manager_insert ON public.menu_items
  FOR INSERT TO authenticated WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));
CREATE POLICY menu_items_manager_update ON public.menu_items
  FOR UPDATE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']))
  WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));
CREATE POLICY menu_items_manager_delete ON public.menu_items
  FOR DELETE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));

CREATE POLICY modifier_groups_member_select ON public.menu_modifier_groups
  FOR SELECT TO authenticated USING (private.has_hotel_role(hotel_id));
CREATE POLICY modifier_groups_manager_insert ON public.menu_modifier_groups
  FOR INSERT TO authenticated WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));
CREATE POLICY modifier_groups_manager_update ON public.menu_modifier_groups
  FOR UPDATE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']))
  WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));
CREATE POLICY modifier_groups_manager_delete ON public.menu_modifier_groups
  FOR DELETE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));

CREATE POLICY modifiers_member_select ON public.menu_item_modifiers
  FOR SELECT TO authenticated USING (private.has_hotel_role(hotel_id));
CREATE POLICY modifiers_manager_insert ON public.menu_item_modifiers
  FOR INSERT TO authenticated WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));
CREATE POLICY modifiers_manager_update ON public.menu_item_modifiers
  FOR UPDATE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']))
  WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));
CREATE POLICY modifiers_manager_delete ON public.menu_item_modifiers
  FOR DELETE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));

CREATE POLICY dietary_tags_authenticated_read ON public.dietary_tags
  FOR SELECT TO authenticated USING (true);

CREATE POLICY item_dietary_tags_member_select ON public.menu_item_dietary_tags
  FOR SELECT TO authenticated USING (private.has_hotel_role(hotel_id));
CREATE POLICY item_dietary_tags_manager_insert ON public.menu_item_dietary_tags
  FOR INSERT TO authenticated WITH CHECK (
    verified_by = (SELECT auth.uid()) AND private.has_hotel_role(hotel_id, ARRAY['owner', 'manager'])
  );
CREATE POLICY item_dietary_tags_manager_delete ON public.menu_item_dietary_tags
  FOR DELETE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));

CREATE POLICY tables_member_select ON public.restaurant_tables
  FOR SELECT TO authenticated USING (private.has_hotel_role(hotel_id));
CREATE POLICY tables_manager_insert ON public.restaurant_tables
  FOR INSERT TO authenticated WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));
CREATE POLICY tables_manager_update ON public.restaurant_tables
  FOR UPDATE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']))
  WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));
CREATE POLICY tables_manager_delete ON public.restaurant_tables
  FOR DELETE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager']));

CREATE POLICY sessions_member_select ON public.dining_sessions
  FOR SELECT TO authenticated USING (private.has_hotel_role(hotel_id));
CREATE POLICY sessions_staff_insert ON public.dining_sessions
  FOR INSERT TO authenticated WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager', 'staff']));
CREATE POLICY sessions_staff_update ON public.dining_sessions
  FOR UPDATE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager', 'staff']))
  WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager', 'staff']));

CREATE POLICY orders_member_select ON public.orders
  FOR SELECT TO authenticated USING (private.has_hotel_role(hotel_id));
CREATE POLICY order_items_member_select ON public.order_items
  FOR SELECT TO authenticated USING (private.has_hotel_role(hotel_id));

CREATE POLICY service_requests_member_select ON public.service_requests
  FOR SELECT TO authenticated USING (private.has_hotel_role(hotel_id));
CREATE POLICY service_requests_member_insert ON public.service_requests
  FOR INSERT TO authenticated WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager', 'staff']));
CREATE POLICY service_requests_member_update ON public.service_requests
  FOR UPDATE TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager', 'staff']))
  WITH CHECK (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager', 'staff']));

CREATE POLICY payments_billing_select ON public.payments
  FOR SELECT TO authenticated USING (private.has_hotel_role(hotel_id, ARRAY['owner', 'manager', 'billing']));
CREATE POLICY feedback_member_select ON public.feedback
  FOR SELECT TO authenticated USING (private.has_hotel_role(hotel_id));
CREATE POLICY audit_manager_select ON public.audit_events
  FOR SELECT TO authenticated USING (
    hotel_id IS NOT NULL AND private.has_hotel_role(hotel_id, ARRAY['owner', 'manager'])
  );

CREATE OR REPLACE FUNCTION public.submit_order(
  p_hotel_id uuid,
  p_dining_session_id uuid,
  p_idempotency_key text,
  p_items jsonb,
  p_notes text DEFAULT NULL
)
RETURNS TABLE (created_order_id uuid, created_order_number bigint, duplicate_submission boolean)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_key text := btrim(p_idempotency_key);
  v_notes text := nullif(btrim(p_notes), '');
  v_request_hash text;
  v_existing_id uuid;
  v_existing_hash text;
  v_order_id uuid;
  v_order_number bigint;
  v_currency text;
  v_line jsonb;
  v_item_id uuid;
  v_quantity integer;
  v_modifier_json jsonb;
  v_modifier_ids uuid[];
  v_valid_modifier_count integer;
  v_invalid_group_count integer;
  v_modifier_total bigint;
  v_modifier_snapshot jsonb;
  v_item public.menu_items%ROWTYPE;
  v_line_total bigint;
  v_order_total bigint := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'authenticated user required' USING ERRCODE = '42501';
  END IF;
  IF NOT private.has_hotel_role(p_hotel_id, ARRAY['owner', 'manager', 'staff']) THEN
    RAISE EXCEPTION 'active hotel membership required' USING ERRCODE = '42501';
  END IF;
  IF v_key IS NULL OR length(v_key) > 128 THEN
    RAISE EXCEPTION 'idempotency key must be 1 to 128 characters' USING ERRCODE = '22023';
  END IF;
  IF v_notes IS NOT NULL AND length(v_notes) > 2000 THEN
    RAISE EXCEPTION 'order notes exceed 2000 characters' USING ERRCODE = '22023';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 50 THEN
    RAISE EXCEPTION 'items must be an array with 1 to 50 entries' USING ERRCODE = '22023';
  END IF;

  v_request_hash := pg_catalog.encode(
    extensions.digest(
      pg_catalog.convert_to(
        pg_catalog.jsonb_build_object(
          'hotel_id', p_hotel_id,
          'dining_session_id', p_dining_session_id,
          'items', p_items,
          'notes', v_notes
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  SELECT o.id, o.request_hash, o.order_number
    INTO v_existing_id, v_existing_hash, v_order_number
    FROM public.orders AS o
    WHERE o.hotel_id = p_hotel_id AND o.idempotency_key = v_key;
  IF FOUND THEN
    IF v_existing_hash <> v_request_hash THEN
      RAISE EXCEPTION 'idempotency key was already used for a different request' USING ERRCODE = '22023';
    END IF;
    RETURN QUERY SELECT v_existing_id, v_order_number, true;
    RETURN;
  END IF;

  SELECT s.currency INTO v_currency
    FROM public.dining_sessions AS s
    JOIN public.restaurant_tables AS t ON t.hotel_id = s.hotel_id AND t.id = s.table_id
    WHERE s.hotel_id = p_hotel_id
      AND s.id = p_dining_session_id
      AND s.status = 'open'
      AND s.closed_at IS NULL
      AND t.status = 'active'
      AND EXISTS (SELECT 1 FROM public.hotels AS h WHERE h.id = s.hotel_id AND h.status = 'active')
    FOR UPDATE OF s;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'dining session is not open for this hotel' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.orders (hotel_id, dining_session_id, currency, status, notes, idempotency_key, request_hash)
    VALUES (p_hotel_id, p_dining_session_id, v_currency, 'submitted', v_notes, v_key, v_request_hash)
    ON CONFLICT (hotel_id, idempotency_key) DO NOTHING
    RETURNING id, order_number INTO v_order_id, v_order_number;

  IF v_order_id IS NULL THEN
    SELECT o.id, o.request_hash, o.order_number
      INTO v_existing_id, v_existing_hash, v_order_number
      FROM public.orders AS o
      WHERE o.hotel_id = p_hotel_id AND o.idempotency_key = v_key;
    IF v_existing_hash <> v_request_hash THEN
      RAISE EXCEPTION 'idempotency key was already used for a different request' USING ERRCODE = '22023';
    END IF;
    RETURN QUERY SELECT v_existing_id, v_order_number, true;
    RETURN;
  END IF;

  FOR v_line IN SELECT value FROM pg_catalog.jsonb_array_elements(p_items) AS items(value)
  LOOP
    IF pg_catalog.jsonb_typeof(v_line) IS DISTINCT FROM 'object'
       OR pg_catalog.jsonb_typeof(v_line->'menu_item_id') IS DISTINCT FROM 'string'
       OR pg_catalog.jsonb_typeof(v_line->'quantity') IS DISTINCT FROM 'number'
       OR (v_line->>'quantity') !~ '^[0-9]+$' THEN
      RAISE EXCEPTION 'each item requires a UUID menu_item_id and integer quantity' USING ERRCODE = '22023';
    END IF;
    v_item_id := (v_line->>'menu_item_id')::uuid;
    v_quantity := (v_line->>'quantity')::integer;
    IF v_quantity NOT BETWEEN 1 AND 99 THEN
      RAISE EXCEPTION 'quantity must be between 1 and 99' USING ERRCODE = '22023';
    END IF;

    v_modifier_json := COALESCE(v_line->'modifier_ids', '[]'::jsonb);
    IF pg_catalog.jsonb_typeof(v_modifier_json) IS DISTINCT FROM 'array'
       OR pg_catalog.jsonb_array_length(v_modifier_json) > 50 THEN
      RAISE EXCEPTION 'modifier_ids must be an array with at most 50 entries' USING ERRCODE = '22023';
    END IF;
    IF EXISTS (
      SELECT 1 FROM pg_catalog.jsonb_array_elements(v_modifier_json) AS modifier(value)
      WHERE pg_catalog.jsonb_typeof(modifier.value) IS DISTINCT FROM 'string'
    ) THEN
      RAISE EXCEPTION 'modifier_ids must contain UUID strings' USING ERRCODE = '22023';
    END IF;
    SELECT COALESCE(pg_catalog.array_agg((modifier.value #>> '{}')::uuid), ARRAY[]::uuid[])
      INTO v_modifier_ids
      FROM pg_catalog.jsonb_array_elements(v_modifier_json) AS modifier(value);
    IF pg_catalog.cardinality(v_modifier_ids) <> (
      SELECT count(DISTINCT selected.id)::integer FROM pg_catalog.unnest(v_modifier_ids) AS selected(id)
    ) THEN
      RAISE EXCEPTION 'a modifier may only be selected once' USING ERRCODE = '22023';
    END IF;

    SELECT mi.* INTO v_item
      FROM public.menu_items AS mi
      JOIN public.menu_categories AS mc ON mc.hotel_id = mi.hotel_id AND mc.id = mi.category_id
      WHERE mi.hotel_id = p_hotel_id
        AND mi.id = v_item_id
        AND mi.is_published
        AND mi.is_available
        AND mi.archived_at IS NULL
        AND mc.is_active
        AND mc.is_published
        AND mc.archived_at IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'menu item is missing, unavailable, unpublished, or belongs to another hotel' USING ERRCODE = '22023';
    END IF;

    SELECT count(*)::integer INTO v_valid_modifier_count
      FROM public.menu_item_modifiers AS mim
      WHERE mim.hotel_id = p_hotel_id
        AND mim.menu_item_id = v_item_id
        AND mim.id = ANY(v_modifier_ids)
        AND mim.is_active
        AND mim.archived_at IS NULL
        AND EXISTS (
          SELECT 1 FROM public.menu_modifier_groups AS g
          WHERE g.hotel_id = mim.hotel_id AND g.menu_item_id = mim.menu_item_id
            AND g.id = mim.group_id AND g.is_active AND g.archived_at IS NULL
        );
    IF v_valid_modifier_count <> pg_catalog.cardinality(v_modifier_ids) THEN
      RAISE EXCEPTION 'a modifier is invalid, unavailable, or belongs to another item' USING ERRCODE = '22023';
    END IF;

    SELECT count(*)::integer INTO v_invalid_group_count
      FROM public.menu_modifier_groups AS g
      WHERE g.hotel_id = p_hotel_id
        AND g.menu_item_id = v_item_id
        AND g.is_active
        AND g.archived_at IS NULL
        AND (
          (SELECT count(*) FROM public.menu_item_modifiers AS mim
           WHERE mim.hotel_id = p_hotel_id AND mim.menu_item_id = v_item_id
             AND mim.group_id = g.id AND mim.id = ANY(v_modifier_ids)
             AND mim.is_active AND mim.archived_at IS NULL) < g.min_selections
          OR
          (SELECT count(*) FROM public.menu_item_modifiers AS mim
           WHERE mim.hotel_id = p_hotel_id AND mim.menu_item_id = v_item_id
             AND mim.group_id = g.id AND mim.id = ANY(v_modifier_ids)
             AND mim.is_active AND mim.archived_at IS NULL) > g.max_selections
        );
    IF v_invalid_group_count > 0 THEN
      RAISE EXCEPTION 'modifier selection does not satisfy group requirements' USING ERRCODE = '22023';
    END IF;

    SELECT COALESCE(pg_catalog.sum(mim.price_adjustment_minor), 0)::bigint,
           COALESCE(
             pg_catalog.jsonb_agg(
               pg_catalog.jsonb_build_object(
                 'group_name_en', g.name_en,
                 'group_name_am', g.name_am,
                 'name_en', mim.name_en,
                 'name_am', mim.name_am,
                 'price_adjustment_minor', mim.price_adjustment_minor
               ) ORDER BY g.sort_order, mim.sort_order, mim.id
             ),
             '[]'::jsonb
           )
      INTO v_modifier_total, v_modifier_snapshot
      FROM public.menu_item_modifiers AS mim
      JOIN public.menu_modifier_groups AS g
        ON g.hotel_id = mim.hotel_id AND g.menu_item_id = mim.menu_item_id AND g.id = mim.group_id
      WHERE mim.hotel_id = p_hotel_id AND mim.menu_item_id = v_item_id
        AND mim.id = ANY(v_modifier_ids) AND mim.is_active AND mim.archived_at IS NULL
        AND g.is_active AND g.archived_at IS NULL;

    IF v_item.price_minor + v_modifier_total < 0 THEN
      RAISE EXCEPTION 'selected modifiers result in a negative unit price' USING ERRCODE = '22023';
    END IF;
    v_line_total := (v_item.price_minor + v_modifier_total) * v_quantity;

    INSERT INTO public.order_items (
      hotel_id, order_id, menu_item_id, quantity,
      item_name_en, item_name_am, item_description_en, item_description_am,
      unit_price_minor, modifier_total_minor, modifier_snapshot, subtotal_minor, status
    ) VALUES (
      p_hotel_id, v_order_id, v_item_id, v_quantity,
      v_item.name_en, v_item.name_am, v_item.description_en, v_item.description_am,
      v_item.price_minor, v_modifier_total, v_modifier_snapshot, v_line_total, 'submitted'
    );
    v_order_total := v_order_total + v_line_total;
  END LOOP;

  UPDATE public.orders AS o SET total_minor = v_order_total WHERE o.id = v_order_id;
  RETURN QUERY SELECT v_order_id, v_order_number, false;
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_order(uuid, uuid, text, jsonb, text) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.submit_order(uuid, uuid, text, jsonb, text) TO authenticated;

-- Synthetic records demonstrate tenant-separated catalogs and operations in development only.
INSERT INTO public.hotels (id, name, slug, description, contact_email, currency, timezone, status, branding)
VALUES
  ('00000000-0000-4000-8000-000000000001', 'SmartServe Demo Addis', 'smartserve-demo-addis', 'Synthetic Phase 2 demo hotel in Addis Ababa.', 'addis-demo@example.invalid', 'ETB', 'Africa/Addis_Ababa', 'active', '{"accent":"#9a3412"}'),
  ('00000000-0000-4000-8000-000000000002', 'SmartServe Demo Bahir Dar', 'smartserve-demo-bahir-dar', 'Synthetic Phase 2 demo hotel in Bahir Dar.', 'bahirdar-demo@example.invalid', 'ETB', 'Africa/Addis_Ababa', 'active', '{"accent":"#0369a1"}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.menu_categories (id, hotel_id, slug, name_en, name_am, description_en, description_am, sort_order, is_published)
VALUES
  ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000001', 'ethiopian-favorites', 'Ethiopian Favorites', 'የኢትዮጵያ ተወዳጅ ምግቦች', 'Demo dishes for tenant A.', 'ለሙከራ የተዘጋጁ ምግቦች።', 1, true),
  ('00000000-0000-4000-8000-000000000102', '00000000-0000-4000-8000-000000000001', 'drinks', 'Drinks', 'መጠጦች', 'Demo drinks for tenant A.', 'ለሙከራ መጠጦች።', 2, true),
  ('00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000002', 'lake-specials', 'Lake Specials', 'የሐይቅ ልዩ ምግቦች', 'Demo dishes for tenant B.', 'ለሙከራ የተዘጋጁ ምግቦች።', 1, true),
  ('00000000-0000-4000-8000-000000000104', '00000000-0000-4000-8000-000000000002', 'coffee', 'Coffee', 'ቡና', 'Demo coffee for tenant B.', 'ለሙከራ ቡና።', 2, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.menu_items (id, hotel_id, category_id, slug, name_en, name_am, description_en, description_am, price_minor, preparation_minutes, is_available, is_published)
VALUES
  ('00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000101', 'misir-wot', 'Misir Wot', 'ምስር ወጥ', 'Red lentil stew with injera.', 'በእንጀራ የሚቀርብ የምስር ወጥ።', 28000, 20, true, true),
  ('00000000-0000-4000-8000-000000000202', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000102', 'buna', 'Ethiopian Coffee', 'የኢትዮጵያ ቡና', 'Freshly brewed coffee.', 'ትኩስ ቡና።', 8000, 8, true, true),
  ('00000000-0000-4000-8000-000000000203', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000103', 'grilled-trout', 'Grilled Trout', 'የተጠበሰ ዓሣ', 'Grilled lake fish with seasonal vegetables.', 'የሐይቅ ዓሣ ከወቅታዊ አትክልቶች ጋር።', 52000, 25, true, true),
  ('00000000-0000-4000-8000-000000000204', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000104', 'demo-unavailable-dish', 'Demo Unavailable Dish', 'ለሙከራ የማይገኝ ምግብ', 'Used to verify availability checks.', 'የመገኘት ሙከራ።', 12000, 15, false, true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.menu_modifier_groups (id, hotel_id, menu_item_id, name_en, name_am, min_selections, max_selections)
VALUES
  ('00000000-0000-4000-8000-000000000301', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000201', 'Extras', 'ተጨማሪዎች', 0, 2)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.menu_item_modifiers (id, hotel_id, menu_item_id, group_id, name_en, name_am, price_adjustment_minor)
VALUES
  ('00000000-0000-4000-8000-000000000401', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000301', 'Extra Injera', 'ተጨማሪ እንጀራ', 3000),
  ('00000000-0000-4000-8000-000000000402', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000201', '00000000-0000-4000-8000-000000000301', 'Extra Egg', 'ተጨማሪ እንቁላል', 7000)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.dietary_tags (id, code, name_en, name_am)
VALUES
  ('00000000-0000-4000-8000-000000000501', 'vegetarian', 'Vegetarian', 'ቬጀቴሪያን'),
  ('00000000-0000-4000-8000-000000000502', 'vegan', 'Vegan', 'ቪጋን'),
  ('00000000-0000-4000-8000-000000000503', 'gluten_free', 'Gluten free', 'ግሉተን የሌለው'),
  ('00000000-0000-4000-8000-000000000504', 'dairy_free', 'Dairy free', 'የወተት ተዋጽኦ የሌለው'),
  ('00000000-0000-4000-8000-000000000505', 'nut_free', 'Nut free', 'ለውዝ የሌለው')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.restaurant_tables (id, hotel_id, table_number, label)
VALUES
  ('00000000-0000-4000-8000-000000000601', '00000000-0000-4000-8000-000000000001', 1, 'Window table'),
  ('00000000-0000-4000-8000-000000000602', '00000000-0000-4000-8000-000000000001', 2, 'Patio table'),
  ('00000000-0000-4000-8000-000000000603', '00000000-0000-4000-8000-000000000002', 1, 'Lake view table'),
  ('00000000-0000-4000-8000-000000000604', '00000000-0000-4000-8000-000000000002', 2, 'Garden table')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.dining_sessions (id, hotel_id, table_id, currency, status, settlement_state, opened_at, closed_at)
VALUES
  ('00000000-0000-4000-8000-000000000701', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000601', 'ETB', 'open', 'partial', now() - interval '30 minutes', NULL),
  ('00000000-0000-4000-8000-000000000702', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000603', 'ETB', 'open', 'unsettled', now() - interval '10 minutes', NULL),
  ('00000000-0000-4000-8000-000000000703', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000602', 'ETB', 'closed', 'settled', now() - interval '2 hours', now() - interval '1 hour')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.orders (id, hotel_id, dining_session_id, currency, status, notes, idempotency_key, request_hash, total_minor, submitted_at)
VALUES
  ('00000000-0000-4000-8000-000000000801', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000701', 'ETB', 'served', 'Synthetic demo order.', 'demo-order-addis-001', repeat('0', 64), 28000, now() - interval '20 minutes'),
  ('00000000-0000-4000-8000-000000000802', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000702', 'ETB', 'submitted', 'Synthetic demo order.', 'demo-order-bahir-dar-001', repeat('1', 64), 52000, now() - interval '5 minutes')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.order_items (id, hotel_id, order_id, menu_item_id, quantity, item_name_en, item_name_am, item_description_en, item_description_am, unit_price_minor, modifier_total_minor, modifier_snapshot, subtotal_minor, status)
VALUES
  ('00000000-0000-4000-8000-000000000901', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000801', '00000000-0000-4000-8000-000000000201', 1, 'Misir Wot', 'ምስር ወጥ', 'Red lentil stew with injera.', 'በእንጀራ የሚቀርብ የምስር ወጥ።', 28000, 0, '[]', 28000, 'served'),
  ('00000000-0000-4000-8000-000000000902', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000802', '00000000-0000-4000-8000-000000000203', 1, 'Grilled Trout', 'የተጠበሰ ዓሣ', 'Grilled lake fish with seasonal vegetables.', 'የሐይቅ ዓሣ ከወቅታዊ አትክልቶች ጋር።', 52000, 0, '[]', 52000, 'submitted')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.service_requests (id, hotel_id, dining_session_id, request_type, status, notes, created_at, resolved_at)
VALUES
  ('00000000-0000-4000-8000-000000001001', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000701', 'call_waiter', 'resolved', 'Synthetic demo request.', now() - interval '15 minutes', now() - interval '12 minutes'),
  ('00000000-0000-4000-8000-000000001002', '00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-000000000702', 'request_bill', 'open', 'Synthetic demo request.', now() - interval '3 minutes', NULL)
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.payments (id, hotel_id, dining_session_id, amount_minor, currency, payment_method, status, external_reference, created_at)
VALUES
  ('00000000-0000-4000-8000-000000001101', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000701', 12000, 'ETB', 'cash', 'recorded', 'demo-cash-addis-001', now() - interval '2 minutes')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.feedback (id, hotel_id, dining_session_id, order_id, rating, comments)
VALUES
  ('00000000-0000-4000-8000-000000001201', '00000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-000000000701', '00000000-0000-4000-8000-000000000801', 5, 'Synthetic demo feedback.')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.audit_events (id, hotel_id, actor_user_id, action, entity_type, entity_id)
VALUES
  ('00000000-0000-4000-8000-000000001301', '00000000-0000-4000-8000-000000000001', NULL, 'demo.seeded', 'hotel', '00000000-0000-4000-8000-000000000001'),
  ('00000000-0000-4000-8000-000000001302', '00000000-0000-4000-8000-000000000002', NULL, 'demo.seeded', 'hotel', '00000000-0000-4000-8000-000000000002')
ON CONFLICT (id) DO NOTHING;
