# Changelog

All notable changes to the Postflare server and web app. The `postflare` CLI has its own changelog in
[cli/CHANGELOG.md](cli/CHANGELOG.md). Versions follow [Semantic Versioning](https://semver.org); from v0.1.0 on, this file
is maintained by [release-please](https://github.com/googleapis/release-please) from
[Conventional Commits](https://www.conventionalcommits.org) (see [docs/RELEASING.md](docs/RELEASING.md)).

## Unreleased

### Features

* **Playbooks**: reusable, versioned recipes for writing posts that perform. 20 built-ins (mobile app and game
  marketing, launches, threads, short-video hooks, LinkedIn stories, polls...) in `playbooks/`, bundled into the Worker;
  custom workspace playbooks with immutable versions (new permission `playbooks.manage` for Owner, Admin and Editor;
  migration 0008). Posts record `playbookId`, `playbookVersion` and an A/B `variant`. Playbooks page (library, detail
  with *Copy agent prompt*, *Use in composer*, *Duplicate & edit*, ranking), a *Playbook* field with its checklist in
  the composer, playbook filter on the posts list and a ranking section in Analytics. API `GET/POST /api/playbooks`,
  `GET/PATCH/DELETE /api/playbooks/:id`, `POST /api/playbooks/:id/duplicate`, `GET /api/playbooks/stats` (lift vs each
  account's baseline, confidence, variants; one D1 query). MCP tools `search_playbooks`, `get_playbook`,
  `get_playbook_stats`; `create_post` / `update_post` take the attribution. The demo workspace has attributed posts.

* **Needs check** post status: when the request that creates a post fails ambiguously (network error, timeout, 5xx
  after sending), the post is no longer retried automatically (that could publish it twice). It goes to `needs_check`
  with "We couldn't confirm whether <platform> accepted the post"; resolve it in the post drawer (Mark as published,
  with an optional URL, or Retry anyway), with `POST /api/posts/:id/resolve`, `pf posts resolve` or the MCP
  `resolve_post` tool. Shown in amber on the calendar, the posts list (filter) and the dashboard.
* **Media retention** (Instance settings, default 30 days, 0 = forever) applied by a new daily cron, plus removal of
  unfinished uploads (2 days) and unused upload-link files (7 days). Media of published posts on platforms that hotlink
  our copy is kept. Storage usage (`GET /api/media/usage`) on the Media page and in Instance settings.

### Bug Fixes

* Publishing: the step that creates the post is never retried by the Workflows engine. Providers mark the create call
  (`commit: true`); safe failures (rate limits, failed uploads before the create call) are retried in separate steps.
  A per-post publish lock stops a re-executed step from calling the platform twice, and every status change of the
  workflow is guarded by the post's revision. Bluesky record keys and Nostr event ids are deterministic, so their
  retries are deduplicated by the platform.
* `recoverStuckPosts` no longer fails posts whose workflow status cannot be read; a post whose workflow died while
  publishing goes to `needs_check`, not `failed`.
* Token refresh: the cron refreshes only tokens expiring within 45 minutes (plus refresh tokens / long-lived tokens
  within 7 days of their own expiry), at most 5 accounts per run, instead of every token expiring within a day on every
  run.
* D1 queries per invocation (Free plan: 50): the media signing key is cached per isolate (`GET /api/media` was ~64
  queries), `POST /api/posts` uses one batch and `createBatch` whatever the number of accounts, publishing reads media
  without a query per chunk, and the metrics clean-up scan and other clean-ups moved to a daily cron
  (`0 3 * * *`), and analytics collection moved to its own trigger (`7,22,37,52 * * * *`) so each run stays under the Free plan's 50 D1 queries. Add both to your `wrangler.local.jsonc` / Deploy-button `wrangler.jsonc` triggers.
* Media used by a draft, scheduled, publishing or needs-check post cannot be deleted (409 with the post ids).

## [0.2.0](https://github.com/FerdiKT/postflare/compare/v0.1.0...v0.2.0) (2026-10-16)


### Features

* admin Overview and usage_events metering ([d6c9ed3](https://github.com/FerdiKT/postflare/commit/d6c9ed35dc8326756ed61b78b6f516941d49347b))
* answer a reply under a published post (replyTo / pf posts comment --reply-to) ([51a8882](https://github.com/FerdiKT/postflare/commit/51a8882e3054c16822c09eb7ae891e22fdcd9823))
* **calendar:** show platform logos on calendar items ([2850dd7](https://github.com/FerdiKT/postflare/commit/2850dd7b0eefcb28ae4b46dd7e2e1d5959a2ae5f))
* comment under a published post (POST /api/posts/:id/comments, pf posts comment) ([03290a8](https://github.com/FerdiKT/postflare/commit/03290a83c3abad81b19d92585637dc2f8d300685))
* **landing:** launch — GitHub and Deploy to Cloudflare buttons are live ([36958b6](https://github.com/FerdiKT/postflare/commit/36958b6cd9050e5a49cc909c105063e834b0a5e9))
* mark X as verified; landing follow button points to [@postflareio](https://github.com/postflareio) ([c07665f](https://github.com/FerdiKT/postflare/commit/c07665f8ec4e6e00e34e973917efb918ed86c169))
* Meta data deletion callback and status page ([9c4335c](https://github.com/FerdiKT/postflare/commit/9c4335c339b75df5e965fae76a98efdc182aa07c))
* platform status (verified/beta/experimental), opt-in experimental integrations, pre-launch landing ([7ad2529](https://github.com/FerdiKT/postflare/commit/7ad252971fe9419f782bd96fababefa919dad058))
* playbooks — recipe library for agent-written posts, with attribution and ranking ([f2cef8e](https://github.com/FerdiKT/postflare/commit/f2cef8e1434c3e688f4ab8f8c205ac76e2e70298))
* **playbooks:** research-backed v2 of all built-ins, with sources ([9a7e3d0](https://github.com/FerdiKT/postflare/commit/9a7e3d0807b22baa7583749b23878487cd25aa70))
* version info, daily update check and release automation ([fdf0f1d](https://github.com/FerdiKT/postflare/commit/fdf0f1dd5dccc6b02d646da7aacbcd5988da888a))


### Bug Fixes

* **cron:** run every job from one */5 trigger ([64efb36](https://github.com/FerdiKT/postflare/commit/64efb362a8222060edf226a11405813842ed6154))
* no double posts (commit semantics + needs_check), token refresh storm, D1 per-invocation budget, media lifecycle ([87d7892](https://github.com/FerdiKT/postflare/commit/87d7892e7a9a8f11d09fa4af27262aef0cd0c266))
* platform auth errors no longer sign the user out; tests for post comments ([72073db](https://github.com/FerdiKT/postflare/commit/72073db9175a27d11720d9e9dda01c21a0c9f52e))
* **x:** video uploads hung forever; keep publishing posts on the dashboard ([276ca15](https://github.com/FerdiKT/postflare/commit/276ca157aaae1e344540acbdb563bd22d97661b2))


### Documentation

* **privacy:** Meta data section, accurate media retention ([4360edf](https://github.com/FerdiKT/postflare/commit/4360edf05389d450e58e10484aea0451b6580cf3))
* v0.1.0 release notes cover playbooks, publish safety, admin overview ([c9f25b6](https://github.com/FerdiKT/postflare/commit/c9f25b6f6829e8881323ffd5a1130c49a668d9c1))

## 0.1.0 (2026-10-13)

First public release.

### Features

* **36 platforms**: X, LinkedIn (profile + pages), Facebook Pages, Instagram (Facebook login and Instagram login),
  Threads, YouTube, TikTok, TikTok for Business, Pinterest, Reddit, Bluesky, Mastodon, Tumblr, VK, Nostr, Farcaster,
  Lemmy, Dribbble, Google Business Profile, Telegram, Discord, Slack, Twitch, Kick, DEV, Hashnode, Medium, WordPress,
  Listmonk, MeWe, Skool, Whop, Moltbook and a generic Webhook. Platform apps (client id/secret) are configured in the
  app, with setup notes per platform.
* **Composer**: one post to many accounts with per-account text and settings, live per-platform limits and checks,
  platform-specific settings (titles, privacy, boards, subreddits, channels, playlists...), threads and first comments,
  previews, drafts.
* **Calendar** (month/week, drag to reschedule) and a **posts list** with publishing logs, retry and cancel.
* **Media library** on R2: multipart uploads up to 5GB, alt text, import from URL. Media is streamed to the platforms in
  chunks, never buffered in the Worker.
* **Publishing with Cloudflare Workflows**: each post sleeps until its time, publishes with retries, polls platform
  processing (videos, Instagram containers, TikTok) and posts follow-ups; a cron re-arms anything lost and refreshes
  tokens before they expire.
* **Analytics**: post metrics (views, reach, likes, comments, shares...) collected about 1h, 24h, 3d, 7d and 30d after
  publishing, then weekly up to 90 days, plus daily follower counts, within the Free plan request budget.
* **Users, workspaces and roles**: several people per instance, workspaces with their own accounts, posts, media, upload
  links and API keys; built-in and custom permission-based roles; instance admins.
* **Invitations**: invite links (7 days) into an existing workspace with a role, or into a new workspace.
* **Upload links**: one-time public pages to upload media from another device (or by an agent), with file caps.
* **REST API** with per-workspace API keys and a built-in **MCP server** (`/mcp`) for AI agents (posts, media, upload
  links, analytics).
* **[`postflare` CLI](cli/README.md)** and a Claude Code skill (`skills/postflare`).
* **Live demo mode** (`DEMO_MODE=true`): a sandboxed, password-less demo workspace that never publishes and resets daily.
* **One-click deploy** (Deploy to Cloudflare) on the Workers Free plan; database migrations are applied automatically.
* **Version and updates**: `GET /api/version`, the running version in Admin → Instance settings, a daily check for new
  releases (one GitHub request a day, `UPDATE_CHECK="false"` turns it off) and an update workflow for copies made with
  the Deploy button.

### Security

* Platform tokens and app secrets encrypted at rest (AES-GCM; `SECRET_KEY` secret recommended).
* CSRF protection on every mutating API route (same-origin check on top of `SameSite=Lax` cookies), login throttling,
  optional `SETUP_TOKEN` for the first-user setup, security headers and a strict CSP for the app.
* API keys act only inside their workspace, never carry instance permissions and cannot mint new keys; workspace
  isolation is enforced on every query (other workspaces' ids answer 404).
* Signed public media links, masked webhook URLs, MCP tool ids encoded so tools cannot reach other routes.
