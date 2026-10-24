# Supabase database

The SQL migrations are the canonical database schema. Phase 2 was applied to `smartserve-dev` (`pvtvhqvvyhumydqsvqtq`, region `eu-central-1`). Its recorded migration versions are `20261024065215`, `20261024065428`, and `20261024070512`.

See the root [README](../README.md) for the schema and tenant-security design, migration commands, and local test workflow. Automated pgTAP checks are in `tests/database/phase2_tenant_isolation.sql`.

Important boundary: the `private` schema and its guest credential hashes are not exposed through Supabase APIs. Anonymous access is intentionally denied until a later backend phase provides a narrowly scoped guest menu/session flow. Phase 2 does not provision Auth users or staff membership lifecycle operations.
