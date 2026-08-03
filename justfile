# karitham.dev — build commands.
#
# SSG (Gleam/Erlang) + client (Gleam/JS) are separate projects.
# `nix develop` drops you in a shell with everything you need.

# Build the static site from scratch.
build: codegen client ssg

# Regenerate types/decoders from vendored Lexicon schemas. We don't
# ask for the typed XRPC client — both SSG and browser go through
# `shared/src/fetch.gleam`'s raw HTTP + decoders instead.
codegen:
	gleam run -m atproto_codegen -- ./lexicons ./shared/src/gen gen app.bsky.,com.atproto.,sh.tangled.,fm.teal.

# Build the JS bundle.
client:
	cd client && gleam build --target javascript

# Build the static site (codegen + client must exist first).
ssg:
	gleam run

# Run all tests (root + shared).
test:
	gleam test && cd shared && gleam test

# Scaffold a new post. Usage: just new my-post-slug
new *ARGS:
	gleam run new {{ARGS}}

# Fetch fresh listening data from PDS, then derive the stats the site embeds.
# One pass: CAR in, stats out — the ~100MB raw dump is never materialized.
# `--covers` enables MusicBrainz/Cover Art Archive lookups for pairs not yet
# cached; with a warm cache the stats step is offline.
refresh:
	#!/usr/bin/env bash
	set -euo pipefail
	mkdir -p priv/cache
	curl -sL "https://eurosky.social/xrpc/com.atproto.sync.getRepo?did=did:plc:kcgwlowulc3rac43lregdawo" \
		-o priv/cache/repo.car
	cd tools/parse-plays && cargo run --release -- refresh ../../priv/cache/repo.car \
		../../priv/cache/plays-stats.json --covers ../../priv/cache/cover-cache.json

# Wipe build artifacts.
clean:
	rm -rf dist build client/build _build priv/cache
