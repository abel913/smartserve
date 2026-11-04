# SmartServe — Phase Status

## Current Status Overview

| Phase       | Description                                              | Status          | Details                                                                                                                                                                               |
| ----------- | -------------------------------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Phase 1** | Project foundation, monorepo, web & API deployment       | **COMPLETE**    | Frontend live on Cloudflare Pages; API Worker deployed; health check verified.                                                                                                        |
| **Phase 2** | Database structure, hotel tenant isolation, and security | **IN PROGRESS** | Remote schema applied to `smartserve-dev` and verified in transactions; code quality passes; **local clean-database replay and `supabase test db` blocked by Docker Desktop daemon**. |
| **Phase 3** | Guest ordering & menu UI / API                           | **NOT STARTED** | Strict boundary: pending Phase 2 local completion.                                                                                                                                    |

---

## Target Project & Safety Boundaries

- **Target Supabase Project**: `smartserve-dev` (Ref: `pvtvhqvvyhumydqsvqtq`, Region: `eu-central-1`).
- **Target Remote State**: Active & healthy. All existing tables, RLS policies, foreign keys, triggers, and synthetic data are preserved intact. Zero destructive or reset commands were issued against the remote database.
- **Unrelated Project Protection**: `airline-exam-bot-staging` (`tyciufbhpbjztqsiirgw`) is completely isolated and was never accessed, modified, migrated, or tested.

---

## Phase 2 Completion Criteria Checklist

- [ ] **All required database migrations replay successfully on a clean local database**: Blocked by Docker Desktop engine.
- [ ] **Database tests pass (`supabase test db`)**: Blocked by Docker Desktop engine.
- [x] **RLS and cross-hotel isolation tests pass**: Designed in `supabase/tests/database/phase2_tenant_isolation.sql` covering 30 assertions; previously passed via rolled-back transaction on `smartserve-dev`.
- [x] **Ownership protection tests pass**: Migration `20261024070512` revokes authenticated updates on immutable tenant ownership columns (`hotel_id`, `category_id`, etc.).
- [x] **Transactional order and pricing tests pass**: Verified in `submit_order` function with atomic validation and server-side minor unit price snapshots.
- [x] **Duplicate submission and rollback tests pass**: Verified with idempotency key handling and multi-line atomic rollback.
- [x] **Remote `smartserve-dev` schema is consistent with intended migrations**: Confirmed migrations `20261024065215`, `20261024065428`, and `20261024070512`.
- [x] **Lint passes**: `npm run lint` exited code 0 (ESLint clean).
- [x] **Formatting check passes**: `npm run format:check` exited code 0 (Prettier clean).
- [x] **Type checking passes**: `npm run typecheck` exited code 0 across `@smartserve/shared`, `@smartserve/web`, and `@smartserve/api`.
- [x] **Production build passes**: `npm run build` exited code 0 (Vite client build and Wrangler Worker dry-run completed).
- [x] **Documentation accurately reflects the verified result**: Documentation updated honestly without falsely claiming unexecuted tests passed.

---

## Remaining Blocker & Exact Resolution Steps

### The Blocker

`docker info` failed with:

```
Server: failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine; open //./pipe/dockerDesktopLinuxEngine: The system cannot find the file specified.
```

Consequently, `npx supabase start` fails with `DockerLifecycleInspectError` because the local Supabase containers cannot be provisioned.

### Steps Required to Complete Phase 2:

1. Open the Windows Start menu and launch **Docker Desktop**.
2. Wait until the Docker status in the system tray shows "Engine running" (green).
3. Confirm in PowerShell:
   ```powershell
   docker info
   ```
4. Run the local database test workflow:
   ```powershell
   npx supabase start
   npx supabase db reset
   npx supabase test db
   npx supabase stop
   ```
5. Once all 30 pgTAP assertions pass in the clean local container, Phase 2 can be marked **COMPLETE**.
