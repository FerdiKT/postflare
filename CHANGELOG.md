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

## [0.3.0](https://github.com/FerdiKT/postflare/compare/v0.2.0...v0.3.0) (2026-10-17)


### Features

* **accounts:** account groups (workspace-scoped brand/project folders) ([95f28a6](https://github.com/FerdiKT/postflare/commit/95f28a685c81a8bd1682ee2fe017ed4bebe9d5c2))
* **auth:** email sign-in links (magic link) ([d404fd7](https://github.com/FerdiKT/postflare/commit/d404fd79d76ffd4cb4819671a59b32af1a5a9391))
* **auth:** magic links behind an instance admin toggle, Cloudflare Email Sending only ([74d9c47](https://github.com/FerdiKT/postflare/commit/74d9c4702f3c4a0ab4a0937901d11c7f344c6fd3))
* **campaigns:** App Store campaign links with click and install/revenue attribution ([88b51ba](https://github.com/FerdiKT/postflare/commit/88b51ba051e28e2656ce8c121f54a87b70650347))
* **campaigns:** web app for App Store campaign links and results ([39c69ba](https://github.com/FerdiKT/postflare/commit/39c69baec3c933dadf237fb6a55e8ea10c166041))
* **cli:** apps, links, --app and installs/revenue in analytics ([e4148ad](https://github.com/FerdiKT/postflare/commit/e4148adc1bace2249111697abf8dfc10c903294a))
* **web:** group accounts by platform or custom group, bulk move, group filters ([d669fde](https://github.com/FerdiKT/postflare/commit/d669fdee64b4e23bf840e636552a3dd6cfa795c4))


### Bug Fixes

* **campaigns:** don't insert tracked links into YouTube Shorts (their links aren't clickable) ([dcac295](https://github.com/FerdiKT/postflare/commit/dcac29546437cce5e509975c36f3b56db0cdb038))
* **youtube:** neutral message for 403 forbidden (it isn't always about comments) ([b3c78b1](https://github.com/FerdiKT/postflare/commit/b3c78b19be2b15b7729138866802bd7bc3aa1b57))


### Documentation

* account groups (API, permissions, README, CLI, skill) ([13a4e4c](https://github.com/FerdiKT/postflare/commit/13a4e4ccaa15066188f1ce47cccac7bdeecf581c))
* App Store campaign links (README section, docs/api.md) ([7ce5dd4](https://github.com/FerdiKT/postflare/commit/7ce5dd4a3d0a509602c29676ba312b1361492422))
* **youtube:** setup notes list the full scope URLs Google's consent screen expects ([88010af](https://github.com/FerdiKT/postflare/commit/88010af68fb0904868791c6c15a780c4f0c1f25c))

## [0.2.0](https://github.com/FerdiKT/postflare/compare/v0.1.0...v0.2.0) (2026-10-17)


### Features

* **youtube:** captions, language fields, playlist creation, localizations, watch time and retention analytics ([5f5c791](https://github.com/FerdiKT/postflare/commit/5f5c791186d652aa11daacdebd5cdb61eb82d6d8))


### Performance

* **youtube:** 32 MiB resumable upload chunks, 24 per step ([2dd98be](https://github.com/FerdiKT/postflare/commit/2dd98be38ff60e45601732ec8caa98c82192e7f1))


### Documentation

* **provider-brief:** chunk size guidance ([33cff2b](https://github.com/FerdiKT/postflare/commit/33cff2bafffa4ccdf38457d3bf091454deadb449))

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
