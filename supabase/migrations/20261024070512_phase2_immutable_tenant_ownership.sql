-- Tenant ownership and stable identifiers must not be mutable through table APIs,
-- even for an account that happens to hold memberships in more than one hotel.
REVOKE UPDATE ON public.menu_categories, public.menu_items,
  public.menu_modifier_groups, public.menu_item_modifiers,
  public.menu_item_dietary_tags, public.restaurant_tables,
  public.service_requests FROM authenticated;

GRANT UPDATE (slug, name_en, name_am, description_en, description_am,
  sort_order, is_active, is_published, archived_at)
  ON public.menu_categories TO authenticated;

GRANT UPDATE (category_id, slug, name_en, name_am, description_en, description_am,
  price_minor, image_path, preparation_minutes, is_available, is_published, archived_at)
  ON public.menu_items TO authenticated;

GRANT UPDATE (name_en, name_am, min_selections, max_selections, sort_order,
  is_active, archived_at)
  ON public.menu_modifier_groups TO authenticated;

GRANT UPDATE (name_en, name_am, price_adjustment_minor, sort_order, is_active, archived_at)
  ON public.menu_item_modifiers TO authenticated;

GRANT UPDATE (table_number, label, qr_identifier, status)
  ON public.restaurant_tables TO authenticated;

GRANT UPDATE (status, notes, resolved_at)
  ON public.service_requests TO authenticated;
