# karitham.dev

Personal site. Gleam SSG that fetches from the AT Protocol (Bluesky PDS + Tangled) at build time, then three small Lustre islands (profile, music, repos) mounted on the server-rendered markup re-fetch fresh data and re-render client-side. Album covers, artist photos, and the profile avatar/banner are mirrored by `just refresh`, then copied into the site at build time, so the visitor's browser never has to fetch from Cover Art Archive, Wikimedia, or the PDS directly - every image is served from `/img/...` on the site itself.

## Build

```sh
nix develop          # or: direnv reload
just refresh         # data pipeline: plays + covers + mirrored images
just build           # codegen -> client JS -> static site -> ./dist/
just test            # run all tests
just clean           # wipe build artifacts
just new my-slug     # scaffold a new post
```

Needs Gleam 1.17+ and Erlang/OTP 28+ - `nix develop` provides everything.

### Environment variables

| Variable   | Default                | Description                          |
| ---------- | ---------------------- | ------------------------------------ |
| `BLOG_URL` | `https://karitham.dev` | Base URL for OG tags, RSS, and links |

```sh
BLOG_URL="http://localhost:8000" just build
```

## Refreshing listening data

The Music section's stats, covers, and page links come from a data pipeline that runs before `just build`:

```sh
just refresh
```

`refresh` streams the play history as a CAR from the PDS, normalizes both Teal play eras (alpha milliseconds and current durations), aggregates top-N artists/albums/tracks per time range, resolves album covers (Cover Art Archive), artist photos (MusicBrainz -> Wikidata -> Wikimedia Commons), and MusicBrainz page links, then writes `priv/cache/plays-stats.json`. It mirrors cover/artist images into `priv/cache/img/` and the profile avatar/banner into `priv/cache/img/profile/`, with a manifest beside each cache so stale files can be garbage-collected and reused without guessing.

Every lookup is cache-first with per-endpoint rate limiting, jittered retries, and `Retry-After` handling. With a warm cache the resolution and image steps are offline; the CAR and profile fetches still touch the network, and only new images are downloaded. A failed or interrupted run never corrupts the caches (atomic writes), and the next run re-does what did not finish.

CI runs `just refresh && just build` on every push and caches `priv/cache/*.json` + `priv/cache/img` between runs, so deploys only resolve and download what's new. The whole `priv/cache` dir is gitignored and wiped by `just clean`.

## Adding a post

```sh
just new my-post-slug
```

Scaffolds `priv/posts/my-post-slug/index.md` with today's date and `draft: true`.
Flip `draft: false` to publish.

Or create a directory manually:

```
priv/posts/my-post/
  index.md
  hero.png          # optional hero/banner image
  diagram.png       # -> /posts/my-post/diagram.png
```

Frontmatter:

```markdown
---
title: My Post
description: short summary
date: 2026-07-18
tags: [gleam, atproto]
draft: true
image: hero.png
---
```

Slug is the directory name. Build validates required fields and fails with a clear
error if something's wrong.

## Layout

Four components:

| Component               | Role                                                                                                                                                                                           |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`shared/`**           | Model types, generated decoders, view components, DOM id constants (compiled to both Erlang and JS)                                                                                            |
| **root**                | SSG - fetches data, mirrors images, renders, writes `dist/`                                                                                                                                    |
| **`client/`**           | Three Lustre islands on the server-rendered markup - re-fetch on load and tab visibility, plays poll every 30s. `just client` builds one self-executing minified module via `lustre/dev build` |
| **`tools/parse-plays`** | Rust CLI - CAR -> normalized plays, cover/artist resolution, image + profile mirroring                                                                                                         |

## Tests

```sh
just test
# or, per suite:
gleam test && (cd shared && gleam test) && (cd client && gleam test)
```
