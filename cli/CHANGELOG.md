# Changelog

Changes to the `postflare` CLI ([npm](https://www.npmjs.com/package/postflare)). It is released separately from the
server, with tags `cli-v<version>`; the server's changes are in the [root changelog](../CHANGELOG.md). From 0.1.0 on this
file is maintained by release-please from Conventional Commits touching `cli/`.

## [0.2.0](https://github.com/FerdiKT/postflare/compare/cli-v0.1.0...cli-v0.2.0) (2026-10-13)


### Features

* **cli:** postflare version command and server compatibility warning ([e10340b](https://github.com/FerdiKT/postflare/commit/e10340ba4ca196440412521b94cbb551fce777ef))
* version info, daily update check and release automation ([fdf0f1d](https://github.com/FerdiKT/postflare/commit/fdf0f1dd5dccc6b02d646da7aacbcd5988da888a))

## 0.1.0 (2026-10-13)

First release.

### Features

* `login` / `logout` / `whoami` / `workspaces` with named profiles (`~/.config/postflare/config.json`, mode 0600) or
  `POSTFLARE_URL` + `POSTFLARE_API_KEY`.
* `accounts`, `accounts options`, `platforms`: connected accounts, platform limits and per-post settings.
* `media upload` (streamed, multipart above 90MB up to 5GB, progress bar), `media list|import|rm`, `upload-link`.
* `post`: natural dates (`--at "tomorrow 9:00"`), several accounts, local files uploaded on the fly, per-platform
  settings (`--set tiktok.privacy_level=...`), threads, drafts, dry runs; `posts show|edit|cancel|retry|rm`.
* `analytics`, `analytics top`, `analytics refresh`.
* `--json` on every command, stable exit codes (0 ok, 1 error, 2 usage). Node.js 20+, no dependencies.
