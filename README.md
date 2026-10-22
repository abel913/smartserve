# smartserve

AI-powered, Amharic-enabled smart menu and hotel dining platform built with React, Hono, Supabase, and Cloudflare.

Phase 1 establishes the React guest experience, Hono API, shared types, and local tooling.

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

Wrangler authentication succeeded, but Cloudflare rejected both project creation and Worker deployment because the account email is not verified. No Pages project or API Worker was created, so there are no live URLs to verify. The account currently reports `default_usage_model: standard`; Cloudflare describes Standard as the usage model for Workers Paid accounts. I did not change billing or deploy the API under that setting. Use a Workers Free account before retrying the API deployment. Wrangler reports the account's `workers.dev` subdomain as `smartserve`.

To unblock deployment, verify the Cloudflare account email from **Cloudflare Dashboard → Profile → Email Address** (select **Send verification email** if shown, then follow the link in the email). Confirm the Workers Free plan in the dashboard, then retry the steps above. Cloudflare's [email verification instructions](https://developers.cloudflare.com/fundamentals/user-profiles/verify-email-address/) explain how to resend the message if needed.

## Supabase

The `supabase/` directory is reserved for local configuration and migrations. Phase 1 creates no application tables. Supabase access was verified for `smartserve-dev` (project ref `pvtvhqvvyhumydqsvqtq`, region `eu-central-1`, status `ACTIVE_HEALTHY`). No Supabase schema changes were made. `airline-exam-bot-staging` was not modified.
