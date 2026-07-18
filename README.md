# karitham.dev

Personal site. Gleam SSG that fetches from the AT Protocol (Bluesky PDS + Tangled) at build time, hydrates client-side with a Lustre component tree.

## Build

```sh
nix develop          # or: direnv reload
just build           # codegen → client JS → static site → ./dist/
just test            # run all tests
just clean           # wipe build artifacts
just new my-slug     # scaffold a new post
```

Needs Gleam 1.17+ and Erlang/OTP 28+ — `nix develop` provides everything.

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
  diagram.png       # → /posts/my-post/diagram.png
```

Frontmatter:

```markdown
---
title: My Post
description: short summary
date: 2026-07-18
tags: [gleam, atproto]
draft: true
---
```

Slug is the directory name. Build validates required fields and fails with a clear
error if something's wrong.

## Layout

Three Gleam packages sharing generated types, decoders, and view code:

| Package       | Role                                                                              |
| ------------- | --------------------------------------------------------------------------------- |
| **`shared/`** | Model types, generated decoders, view components (compiled to both Erlang and JS) |
| **root**      | SSG — fetches data, renders, writes `dist/`                                       |
| **`client/`** | Browser bundle — fetches fresh data on page load, polls plays every 30s           |

## Tests

```sh
just test
# or:
gleam test && cd shared && gleam test
```
