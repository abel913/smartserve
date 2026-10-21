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

Authenticate Wrangler with a Cloudflare account using `npx wrangler login`. Deploy the API with `npm run deploy:api`; this publishes the Worker to its `workers.dev` URL. Deploy the web app with `npm run deploy:web` after creating a Cloudflare Pages project named `smartserve` in your Cloudflare account; Pages serves the Vite build from `apps/web/dist`.

Set frontend variables in the Pages project settings before enabling Supabase features. Configure server-only values with `npx wrangler secret put NAME --config apps/api/wrangler.jsonc`. A deployment is complete only after checking the Pages URL and the deployed API's `/health` URL.

## Supabase

The `supabase/` directory is reserved for local configuration and migrations. Phase 1 creates no application tables. Confirm and link the intended development project before later schema work.
