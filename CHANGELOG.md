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

## [0.3.0](https://github.com/FerdiKT/postflare/compare/v0.2.0...v0.3.0) (2026-10-23)


### Features

* access requests (signup_mode apply) with admin review, invitations and notifications ([eaac3dd](https://github.com/FerdiKT/postflare/commit/eaac3dd8c247fff6fd940f1a31c477800673d4f5))
* **accounts:** account groups (workspace-scoped brand/project folders) ([95f28a6](https://github.com/FerdiKT/postflare/commit/95f28a685c81a8bd1682ee2fe017ed4bebe9d5c2))
* **api:** iOS app backend: device tokens, pairing codes, devices and APNs push ([7c5526c](https://github.com/FerdiKT/postflare/commit/7c5526c0351791ee45f89a5a6a8f1f8c682f9bd5))
* **auth:** email sign-in links (magic link) ([d404fd7](https://github.com/FerdiKT/postflare/commit/d404fd79d76ffd4cb4819671a59b32af1a5a9391))
* **auth:** magic links behind an instance admin toggle, Cloudflare Email Sending only ([74d9c47](https://github.com/FerdiKT/postflare/commit/74d9c4702f3c4a0ab4a0937901d11c7f344c6fd3))
* **auth:** optional Cloudflare Turnstile bot check on sign-up, sign-in links and repeated failed sign-ins ([67505d7](https://github.com/FerdiKT/postflare/commit/67505d711c3cf5d316aa02ab5fc20ceb2ed0bb6b))
* **auth:** public sign-up with email verification ([9412318](https://github.com/FerdiKT/postflare/commit/94123181f276e77dbbe5a130c3adf6129d86fcfb))
* **auth:** sign in on the web with the iOS app (QR or push with number matching) ([c69f7d2](https://github.com/FerdiKT/postflare/commit/c69f7d2c339bbd9c5185a953fc2d6619fbb967d0))
* **billing:** OAuth callbacks over the account limit name it in the redirect (planLimit) ([3bb421d](https://github.com/FerdiKT/postflare/commit/3bb421ddd1e02e7381fc21dc20c7cd67356e6816))
* **billing:** plans, per-workspace subscriptions, limits and Polar/Stripe/Lemon Squeezy billing ([d4070ae](https://github.com/FerdiKT/postflare/commit/d4070ae3c718fe848ca3387a7bbef64750b5edf0))
* **campaigns:** App Store campaign links with click and install/revenue attribution ([88b51ba](https://github.com/FerdiKT/postflare/commit/88b51ba051e28e2656ce8c121f54a87b70650347))
* **campaigns:** web app for App Store campaign links and results ([39c69ba](https://github.com/FerdiKT/postflare/commit/39c69baec3c933dadf237fb6a55e8ea10c166041))
* **cli:** apps, links, --app and installs/revenue in analytics ([e4148ad](https://github.com/FerdiKT/postflare/commit/e4148adc1bace2249111697abf8dfc10c903294a))
* instance-aware Privacy Policy, Terms and Data Deletion pages with Admin → Settings → Legal & contact ([ef97303](https://github.com/FerdiKT/postflare/commit/ef973039c689f8f7f631ba29794272aa5f5ab234))
* **ios:** English and Turkish localization incl. push loc-keys ([4247522](https://github.com/FerdiKT/postflare/commit/424752293ebd644eac3e7b9150b8766b3f54ccb7))
* **ios:** media thumbnails, persistent image cache and cached video posters ([1d9ca83](https://github.com/FerdiKT/postflare/commit/1d9ca8360993e05aa0e23ee0929574f17500160d))
* **ios:** post detail with platform previews, collapsible text and a fullscreen media viewer ([21c77bc](https://github.com/FerdiKT/postflare/commit/21c77bcdad8ee5afcce6bee5e176b090fd9770d7))
* **ios:** review access requests (list, detail, approve with invite link, reject) and the access_request push ([4c027ea](https://github.com/FerdiKT/postflare/commit/4c027ea1eb672ced773bb4cd7d3f9b3812a5724b))
* **ios:** Settings → About links to the server's Privacy Policy, Terms and Data Deletion ([6b5b6b4](https://github.com/FerdiKT/postflare/commit/6b5b6b413949f60865d0322255be3a67497337bb))
* **ios:** sign-in, home, posts, composer, accounts, analytics and settings ([eb8ae53](https://github.com/FerdiKT/postflare/commit/eb8ae5372aeb272ac8330cd3b925da92787735f4))
* **ios:** Up next and Today widgets ([ee849f1](https://github.com/FerdiKT/postflare/commit/ee849f1310575205c5cef20627487f860cae03a5))
* **ios:** XcodeGen project, brand assets and the shared core (API client, models, keychain) ([b27aaba](https://github.com/FerdiKT/postflare/commit/b27aaba633c94a73d2a2e82f887f71b1d56fcf2f))
* **landing:** real Sign up link and a pricing section when hosted mode is on ([59e1070](https://github.com/FerdiKT/postflare/commit/59e1070581a58d038d6fc3691e794f12f7abaaba))
* new Postflare mark: a calendar page crossed by the flare on Cloudflare orange ([83a4788](https://github.com/FerdiKT/postflare/commit/83a478876224732fb5925640af2df193492585a2))
* serve media from an R2 custom domain (MEDIA_PUBLIC_URL) and add image thumbnails ([3e31e2b](https://github.com/FerdiKT/postflare/commit/3e31e2b199a1e3474005dd8fb204a8c4b2fc5f02))
* **web:** group accounts by platform or custom group, bulk move, group filters ([d669fde](https://github.com/FerdiKT/postflare/commit/d669fdee64b4e23bf840e636552a3dd6cfa795c4))
* **web:** hosted mode UI: Admin → Billing, Billing tab, plan banner, upgrade dialog on 402, sign-up ([202463f](https://github.com/FerdiKT/postflare/commit/202463fe4a775eea2932951db9d9fe7a036e54cc))
* **web:** platform previews in the composer and the post drawer ([2912f1b](https://github.com/FerdiKT/postflare/commit/2912f1b0b1c49bb62f4659472802b10fc0f11ead))
* **web:** Postflare for iPhone card and sign-in with the iPhone app ([13ac5ee](https://github.com/FerdiKT/postflare/commit/13ac5eee54043daeee710640fc9c96faa0d42cbd))
* **web:** Request access page, Admin → Requests and a 3-way sign-up setting ([05c2b4b](https://github.com/FerdiKT/postflare/commit/05c2b4b04fc13014c8c6fd688be41538c0be4b5c))
* **x:** reply to another post (replyTo setting: post URL or id) ([9a0938d](https://github.com/FerdiKT/postflare/commit/9a0938d88eb1a5874803a86ea769b14d1c40b010))


### Bug Fixes

* **accounts:** copy account avatars to R2 so expiring platform links stop breaking ([0d78d2f](https://github.com/FerdiKT/postflare/commit/0d78d2f6b6c3ad52f6f849999d4473a85397bdfd))
* **accounts:** record reconnects and keep working analytics on reconnect ([d0aec23](https://github.com/FerdiKT/postflare/commit/d0aec23adda45e507014a6658861b6366041ec89))
* **accounts:** show platform names, not raw provider ids, before the catalog loads ([ff89302](https://github.com/FerdiKT/postflare/commit/ff893026a57c71f7093a1e2d16b5fb08fa15c26d))
* **billing:** count monthly posts by publish month, deletion-proof ([512bc91](https://github.com/FerdiKT/postflare/commit/512bc91868f2a257a2432dd382d6dd5363f01bc2))
* **campaigns:** don't insert tracked links into YouTube Shorts (their links aren't clickable) ([dcac295](https://github.com/FerdiKT/postflare/commit/dcac29546437cce5e509975c36f3b56db0cdb038))
* **instagram:** stop signing users out of instagram.com on connect ([3e63bec](https://github.com/FerdiKT/postflare/commit/3e63bec48eb95b90877df07612a380426885077b))
* **mcp:** filter list_accounts by platform and accept postId in post tools ([0b2233f](https://github.com/FerdiKT/postflare/commit/0b2233f29572f33792f82e782f5526863f81185f))
* Threads login on threads.com, readable post settings and labels ([63b2f9f](https://github.com/FerdiKT/postflare/commit/63b2f9f851b369dad0b05b12f8889991da3e38d0))
* **workflow:** link first comments to the comment, or say it is the post's link ([1dc2fcc](https://github.com/FerdiKT/postflare/commit/1dc2fcc4790815001fc3784f6e8dfcc6b3979dc8))
* **workflow:** log successful first comments and follow-ups on the post ([50a615a](https://github.com/FerdiKT/postflare/commit/50a615aa2fb2bfde4b031968558a8ed6024a81f6))
* **youtube:** neutral message for 403 forbidden (it isn't always about comments) ([b3c78b1](https://github.com/FerdiKT/postflare/commit/b3c78b19be2b15b7729138866802bd7bc3aa1b57))


### Documentation

* access requests (sign-up by application) in the README, hosted spec, API, iOS API and SECURITY ([33a6f01](https://github.com/FerdiKT/postflare/commit/33a6f01064163c8420e0b6e7b3147faeaa44c43c))
* account groups (API, permissions, README, CLI, skill) ([13a4e4c](https://github.com/FerdiKT/postflare/commit/13a4e4ccaa15066188f1ce47cccac7bdeecf581c))
* App Store campaign links (README section, docs/api.md) ([7ce5dd4](https://github.com/FerdiKT/postflare/commit/7ce5dd4a3d0a509602c29676ba312b1361492422))
* hosted mode (API, README, security notes, billing.manage) ([86c6fbd](https://github.com/FerdiKT/postflare/commit/86c6fbd04a333bb5ca3a051ed479a0f8639c7dd1))
* iOS app API reference, APNs setup, device token and QRLJacking notes ([d7c3c4a](https://github.com/FerdiKT/postflare/commit/d7c3c4a2bacd07944d52e5021bbdbb4ce72452a1))
* **ios:** iOS app README, release scripts and a pointer in the root README ([dd20e95](https://github.com/FerdiKT/postflare/commit/dd20e9578a8cc3a287fa6a9b4d70080ed7254faf))
* static license badge (the GitHub-API one shows "invalid" when shields.io is rate limited) ([2484c11](https://github.com/FerdiKT/postflare/commit/2484c11d17871809b8512ef7adc915cf2556e22b))
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
