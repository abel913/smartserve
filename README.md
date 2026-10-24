# smartserve

AI-powered, Amharic-enabled smart menu and hotel dining platform built with React, Hono, Supabase, and Cloudflare.

Phase 1 establishes the application foundation. Phase 2 adds the initial hotel-scoped Supabase schema, access policies, and database tests. The current web and API experiences are still the Phase 1 welcome page and health endpoint; guest ordering and staff authentication are later phases.

## Requirements

- Node.js 20.19+ or 22.12+ and npm
- Cloudflare account for deployment
- Supabase account with access to the `smartserve-dev` project for later integration

## Installation

```sh
git clone https://github.com/abel913/smartserve.git
cd smartserve
npm install
```

Copy `.env.example` to `.env` and fill in only the public Supabase project URL and publishable key when available. The Phase 1 welcome page and health endpoint do not require Supabase credentials.

## Local development

```sh
npm run dev
```

The Vite frontend runs at `http://localhost:5173`; the Hono API runs at `http://localhost:8787`. Check the API at `http://localhost:8787/health`.

Run project checks and builds with:

```sh
npm run lint
npm run format:check
npm run typecheck
npm run build
```

## Environment variables

| Variable                        | Used by     | Description                                                                                               |
| ------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------- |
| `VITE_SUPABASE_URL`             | Browser     | Supabase project URL; public value.                                                                       |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Browser     | Supabase publishable key; safe for a browser when database access is protected by RLS.                    |
| `VITE_API_URL`                  | Browser     | API base URL; local default is `http://localhost:8787`.                                                   |
| `SUPABASE_SECRET_KEY`           | Server only | Reserved for trusted server-side use. Never prefix with `VITE_`, commit it, or expose it to browser code. |

Keep real secrets in local ignored environment files or Cloudflare Worker secrets. Never commit `.env` or `.dev.vars`.

## Deployment

The frontend is a static Cloudflare Pages site. The API is a Cloudflare Worker with a `workers.dev` URL. Cloudflare makes its Workers Free plan available by default; the Workers Paid plan starts at $5 per month. This project does not configure paid add-ons. See Cloudflare's [Workers pricing](https://developers.cloudflare.com/workers/platform/pricing/) and [Pages limits](https://developers.cloudflare.com/pages/platform/limits/).

1. Sign in to the intended Cloudflare account and verify its email address. Confirm that the account is using Workers Free before deploying the API.
2. Authenticate Wrangler with `npx wrangler login`.
3. Create the Pages project once: `npx wrangler pages project create smartserve --production-branch main --force`.
4. Deploy the frontend with `npm run deploy:web` and the API with `npm run deploy:api`.
5. Open the Pages URL and request `/health` on the Worker URL. Treat deployment as complete only after both respond successfully.

Wrangler's newer automatic workspace detection tried to configure this monorepo as a Worker during Pages project creation. The `--force` flag on the project creation command selects the direct Pages workflow. The deploy script uploads only `apps/web/dist`.

Set frontend variables in the Pages project settings before enabling Supabase features. Configure server-only values with `npx wrangler secret put NAME --config apps/api/wrangler.jsonc`.

### Cloudflare deployment status (October 22, 2026)

The static frontend is deployed at [https://smartserve.pages.dev/](https://smartserve.pages.dev/) and returned HTTP 200 when checked. The latest production deployment URL was `https://77ea50f9.smartserve.pages.dev`.

The Hono API is deployed with `apps/api/wrangler.jsonc` at [https://smartserve-api.smartserve.workers.dev/](https://smartserve-api.smartserve.workers.dev/). Its `/health` endpoint returned HTTP 200 with valid JSON (`status: ok`, `service: smartserve-api`, and an ISO timestamp). The account owner confirmed Workers Free before deployment. No plan or billing setting was changed.

The Workers account settings API reports `default_usage_model: standard` and `green_compute: false`; Cloudflare documents Standard as the usage model for Workers Paid accounts. Subscription details could not be read because the Wrangler token lacks billing-read access (HTTP 403). If the Standard setting is unexpected, confirm the account plan in Cloudflare Dashboard → Workers & Pages → Usage/Billing. The API deployment succeeded and both services returned HTTP 200.

Pages project creation now succeeds. Cloudflare's user API does not expose an `email_verified` field; the Pages creation success shows the earlier verification gate no longer blocks Pages. The profile page is the authoritative way to check the verification badge. See Cloudflare's [email verification instructions](https://developers.cloudflare.com/fundamentals/user-profiles/verify-email-address/).

The Pages project has no production or preview environment variables or secrets configured. The current welcome page does not use `VITE_API_URL` or call the API, so it has no production API URL or CORS dependency yet. `wrangler secret list` returned no Worker secrets.

## Supabase database

Phase 2 creates the initial database foundation in the verified `smartserve-dev` project (`pvtvhqvvyhumydqsvqtq`, `eu-central-1`). The migrations are the source of truth:

- `20261024065215_phase2_hotel_tenant_schema.sql` creates the hotel and dining model, tenant-safe foreign keys, indexes, RLS, order submission function, and synthetic demo records for two hotels.
- `20261024065428_phase2_privilege_and_trigger_correction.sql` removes direct order writes and restricts the order function to authenticated users.
- `20261024070512_phase2_immutable_tenant_ownership.sql` limits update grants so authenticated clients cannot change tenant ownership or stable row identifiers, even when a user belongs to multiple hotels.

The schema includes hotels and memberships; bilingual categories and dishes; modifier groups/options and dietary tags; tables and dining sessions; private guest credential hashes; orders and immutable price/name snapshots; waiter requests; payment records; feedback; and audit events. Money uses integer minor units. Composite foreign keys keep related records in the same hotel. Historical records are retained with restrictive deletes and menu archival fields.

RLS is enabled on all 17 application tables. Hotel membership is checked by `private.has_hotel_role`, a fixed-search-path security-definer helper that trusts the authenticated JWT user ID, not a client-selected hotel ID. Staff membership records cannot be created or changed through client table grants. Hotel managers can edit hotel configuration and catalog records; orders and order-item snapshots are read-only to clients and are created atomically through `public.submit_order`. Anonymous access is denied, including public menu reads. Guest menu access and private guest-session token exchange must be implemented through a deliberately scoped backend in a later phase. `private.guest_session_credentials` stores only credential hashes and is outside the exposed API schemas.

The development database contains synthetic `smartserve-demo-addis` and `smartserve-demo-bahir-dar` records only. No real user identity or hotel data was added. The order function and future membership policies depend on trusted Supabase Auth identities; Phase 2 did not add sign-in or invitation flows. Do not add broad temporary policies to get around that dependency.

### Apply migrations

After signing the Supabase CLI into an account authorized for SmartServe, link the intended project and apply pending migrations:

```sh
npx supabase login
npx supabase link --project-ref pvtvhqvvyhumydqsvqtq
npx supabase migration list
npx supabase db push
```

Check the linked project reference before applying any migration. Do not use `db reset` against a linked/remote project; it is a destructive reset operation. The two migration versions above were applied to `smartserve-dev` and confirmed in its migration history. `airline-exam-bot-staging` was not modified.

### Recreate locally and run database tests

Install and start Docker Desktop, then use the local Supabase stack only:

```sh
npx supabase start
npx supabase db reset
npx supabase test db
npx supabase stop
```

`supabase db reset` in this sequence resets the local Supabase database, not `smartserve-dev`. The pgTAP suite in `supabase/tests/database/phase2_tenant_isolation.sql` creates synthetic memberships using deferred Auth foreign keys, supplies controlled JWT claims, verifies RLS and order invariants, and rolls back all test fixtures. Never run RLS tests only as a database owner or service role. The suite was executed through the authorized SmartServe Supabase SQL connection in a transaction and its postconditions passed. A local clean-database replay was not verified because Docker Desktop's engine was unavailable during this run.

Phase 2 does not expose a public menu, create Auth users, configure storage buckets, integrate payments, or change Cloudflare. The current frontend and health endpoint do not depend on Supabase.
