# karitham.dev — build commands.
#
# SSG (Gleam/Erlang) + client (Gleam/JS) are separate projects.
# `nix develop` drops you in a shell with everything you need.

# Build the static site from scratch.
build: codegen client ssg

# Regenerate types/decoders from vendored Lexicon schemas. We don't
# ask for the typed XRPC client — both SSG and browser go through
# `shared/src/atproto.gleam`'s raw HTTP + decoders instead. Generate
# into a temp dir and swap it in so a removed or renamed lexicon can't
# leave a stale module behind.
codegen:
	#!/usr/bin/env bash
	set -euo pipefail
	out="$(mktemp -d)"
	trap 'rm -rf "$out"' EXIT
	gleam run -m atproto_codegen -- ./lexicons "$out" gen app.bsky.,com.atproto.,org.tangled.,fm.teal.
	rm -rf shared/src/gen
	mv "$out" shared/src/gen

# Build the JS bundle: one minified, self-executing ES module in
# client/dist/, copied into dist/client/ by the SSG step.
client:
	cd client && gleam run -m lustre/dev build --minify=true --no-html=true

# Build the static site (codegen + client must exist first).
ssg:
	gleam run

# Run all tests (root + shared + client).
test:
	gleam test
	cd shared && gleam test
	cd client && gleam test

# Scaffold a new post. Usage: just new my-post-slug
new *ARGS:
	gleam run new {{ARGS}}

# Fetch fresh listening data from the PDS, then derive the stats the
# site embeds. The CAR streams from curl into the process, so the ~100MB
# dump is never written to disk. `--covers` enables MusicBrainz/Cover Art
# Archive lookups for pairs not yet cached; with a warm cache the resolve
# step is offline. `--images` mirrors cover/artist images into
# priv/cache/img with a manifest and GC; `--profile` mirrors the
# avatar/banner through the same store.
refresh:
	#!/usr/bin/env bash
	set -euo pipefail
	mkdir -p priv/cache priv/cache/img
	curl --fail --retry 3 --retry-delay 1 -sSL \
		"https://eurosky.social/xrpc/com.atproto.sync.getRepo?did=did:plc:kcgwlowulc3rac43lregdawo" \
		| (cd tools/parse-plays && cargo run --quiet --release -- refresh - \
			../../priv/cache/plays-stats.json \
			--covers ../../priv/cache/cover-cache.json \
			--images ../../priv/cache/img \
			--profile karitham.dev)

# Wipe build artifacts.
clean:
	rm -rf dist build client/build client/dist client/.lustre priv/cache
