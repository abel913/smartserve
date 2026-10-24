# SmartServe progress

## Phase 1 — Project foundation and connected accounts

Status: **Complete — frontend and API are deployed and verified**

### Tasks

- [x] Inspect repository and preserve existing resources (active remote contained its original README; its description is preserved).
- [x] Establish `apps/web`, `apps/api`, `packages/shared`, and `supabase`.
- [x] Configure React, Vite, Tailwind CSS, TanStack Query, Hono, and shared TypeScript types.
- [x] Create responsive SmartServe welcome page.
- [x] Add JSON API health endpoint without credentials.
- [x] Configure npm workspaces, lint, format, type checking, and production build scripts.
- [x] Generate npm lockfile.
- [x] Add `.gitignore` and safe `.env.example`.
- [x] Verify access to the `smartserve-dev` Supabase project (`pvtvhqvvyhumydqsvqtq`, `eu-central-1`, `ACTIVE_HEALTHY`); no schema changes made.
- [x] Write `PROJECT_PLAN.md` and this progress file.
- [x] Document installation, development, environment, and deployment in `README.md`.
- [x] Deploy the static frontend to Cloudflare Pages (`https://smartserve.pages.dev/`); verified HTTP 200 on 2026-10-22.
- [x] Deploy the API to Cloudflare Workers using `apps/api/wrangler.jsonc`; `https://smartserve-api.smartserve.workers.dev/health` returns HTTP 200 with valid JSON.
- [x] Run local acceptance checks.
- [x] Confirm Supabase access to `smartserve-dev` without modifying the database.
- [x] Rechecked Cloudflare authentication and account settings on 2026-10-22. Wrangler OAuth is authenticated; Pages project creation now succeeds. Cloudflare's user API omits an `email_verified` field, but successful Pages creation shows the previous email-verification gate no longer blocks that service. Earlier attempts were rejected with Pages error `8000077` and Workers error `10034`.
- [x] Inspected Pages production/preview configuration: no environment variable names or secrets are configured. The frontend currently does not read `VITE_API_URL` or make API requests, so there is no production API URL or CORS dependency in the current welcome page.
- [x] Checked Workers account settings: `default_usage_model` is `standard` and `green_compute` is `false`. Cloudflare documents Standard as the usage model for Workers Paid accounts. The subscription endpoint returns HTTP 403 (the Wrangler token lacks billing read permission), so the subscribed plan and usage totals cannot be independently confirmed. No Worker was deployed to avoid risking paid charges.
- [x] Commit Phase 1 locally as `6992656` (`feat: establish SmartServe phase 1 foundation`).

### Acceptance checks

- [x] Frontend starts locally (HTTP 200) and a production build succeeds.
- [x] API health endpoint returns HTTP 200 JSON locally and when deployed. The deployed response contains `status: "ok"`, `service: "smartserve-api"`, and an ISO timestamp.
- [x] Lint, formatting check, type checking, and production builds pass.
- [x] Lockfile is generated; no real credentials are present in source or frontend code.
- [x] Lockfile is committed with Phase 1.
- [x] `smartserve-dev` is confirmed accessible and active without changing its schema.
- [x] Frontend URL is live and verified: `https://smartserve.pages.dev/` returns HTTP 200.
- [x] API URL is live and verified: `https://smartserve-api.smartserve.workers.dev/health` returns HTTP 200 JSON.

### Verification notes

- The account owner confirmed Workers Free before deployment. No plan or billing settings were changed. The read-only Workers settings API still reports `default_usage_model: standard`; Cloudflare documents Standard as the Workers Paid usage model. Subscription details remain unavailable to this token (HTTP 403, no billing-read scope), so verify the plan in the Cloudflare dashboard if that setting is unexpected.
- Cloudflare project creation previously failed with email verification errors (`8000077` for Pages and `10034` for Workers); Pages and Worker deployment now succeed. The user API does not expose an `email_verified` field.
- Pages project `smartserve` is live at `https://smartserve.pages.dev/`; the latest production deployment was `https://77ea50f9.smartserve.pages.dev`.
- The API Worker `smartserve-api` is deployed at `https://smartserve-api.smartserve.workers.dev/`. Its `/health` endpoint returned HTTP 200 with valid JSON on 2026-10-22.
- No Pages environment variables or secrets are configured. `wrangler secret list` returned no Worker secrets. The welcome page does not call the API, so no production API URL or CORS dependency is currently configured in the frontend.
- Both production URLs passed their HTTP checks. No paid service or billing setting was enabled or changed.
- `smartserve-dev` remains accessible and active; no schema changes were made. `airline-exam-bot-staging` was not modified.

## Phase 2 — Database structure and hotel isolation

Status: **In progress — remote schema and transactional security checks pass; local clean-database replay is still unverified**

### Tasks and verified results

- [x] Re-inspect Git status, repository structure, Supabase configuration, and Phase 1 documentation; the worktree was clean at start.
- [x] Verify the target Supabase project is `smartserve-dev` (`pvtvhqvvyhumydqsvqtq`, `eu-central-1`, `ACTIVE_HEALTHY`) before applying changes. The separate `airline-exam-bot-staging` project was not modified.
- [x] Confirm the pre-Phase-2 public application schema contained no app tables or migration history. Existing Supabase-managed schemas and data were left intact.
- [x] Add the hotel and dining schema, tenant-scoped composite foreign keys, indexes, updated-at/currency triggers, membership helper, RLS policies, and atomic `submit_order` function. Add synthetic demonstration data for two hotels only.
- [x] Record remote migrations `20261024065215` (`phase2_hotel_tenant_schema`), `20261024065428` (`phase2_privilege_and_trigger_correction`), and `20261024070512` (`phase2_immutable_tenant_ownership`) in Supabase history and align the checked-in migration filenames to those IDs.
- [x] Verify the remote schema contains 17 public application tables, all with RLS enabled; 38 public policies, 34 foreign keys, 58 indexes, and 13 public triggers.
- [x] Verify direct order/order-item writes are not granted to authenticated clients; `submit_order` is executable by authenticated users only, and neither `anon` nor `service_role` can execute it. No anonymous table grants exist for hotels.
- [x] Restrict update grants to mutable columns so hotel IDs and stable row identifiers cannot be changed through authenticated table APIs, even by an owner with memberships in multiple hotels.
- [x] Run controlled-JWT remote RLS checks for two identities: a multi-hotel owner sees only their memberships, and a second hotel manager sees only their own hotel. Cross-hotel SELECT, INSERT, UPDATE, and DELETE were denied; a multi-hotel owner also cannot change a catalog row's tenant. An allowed same-hotel catalog update still succeeds. Test identities and memberships were transaction-scoped and rolled back; no Auth users were created.
- [x] Verify order pricing snapshots, selected modifier pricing, idempotent retry, mismatched idempotency rejection, closed-session rejection, unavailable item rejection, and atomic rollback after an invalid later line using a controlled JWT. The database transaction rolled back all test orders.
- [x] Verify the same-hotel category foreign key, unique table number, positive payment amount, duplicate payment reference protection, and hotel-derived session currency. Test rows were rolled back.
- [x] Add `supabase/tests/database/phase2_tenant_isolation.sql` with 30 pgTAP checks and controlled JWT claims. Running the SQL test file through the SmartServe connection reached assertion 30; direct postcondition checks also passed.
- [x] Update README and Supabase instructions with the model, tenant security, migration workflow, test workflow, and Auth/guest-flow dependencies.
- [ ] Recreate the database from migrations and run the standard `supabase test db` CLI in a clean local stack. Docker is installed but its engine is not running (`dockerDesktopLinuxEngine` pipe unavailable). The Supabase CLI session also lists only `airline-exam-bot-staging`; it was not linked to either remote project. Do not link or reset the unrelated project.

### Acceptance checks

- [x] Phase 2 migrations applied to the verified `smartserve-dev` target and confirmed in remote migration history.
- [x] Foreign keys, unique/check constraints, indexes, RLS enablement, and function grants verified in the remote database.
- [x] Cross-hotel tenant isolation verified under two controlled, non-privileged authenticated JWT identities, not as table owner/service role.
- [x] Order creation uses database prices and snapshots, rejects closed/unavailable items and bad quantities, safely handles duplicate requests, and rolls back when any line fails.
- [ ] Clean local database replay and `supabase test db` CLI result. Blocked only by the unavailable local Docker engine; the remote transaction-scoped tests passed.
- [x] Existing frontend/API source was not changed; lint, format check, TypeScript type checks, and production builds passed.
- [x] No secrets, persistent test identities, or changes to another Supabase project were introduced.

### Phase 2 notes

- RLS covers 17 public tables. The `private` schema is not exposed by the Supabase API and stores guest credential hashes only. No actual guests or staff have access until later phases add secure session entry and Auth/membership lifecycle flows.
- The pgTAP extension was created only inside a rolled-back test transaction; the database was not left with an extra extension or test membership.
- Migrations were executed through the authorized Supabase connection. The `npx supabase db push`/local replay workflow has not yet been verified from this machine.
- `npm run lint`, `npm run format:check`, `npm run typecheck`, and `npm run build` passed. The first sandboxed Vite build attempt hit a child-process `spawn EPERM`; rerunning the unchanged build with the approved elevated command completed both the Vite build and Wrangler Worker dry run successfully.
- The first tenant-ownership review found a multi-hotel user could otherwise move a row by changing both its tenant and related foreign key. The third migration now removes authenticated update privileges from ownership columns; a follow-up controlled-JWT test covers this case.
