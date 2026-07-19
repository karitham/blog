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

# Wipe build artifacts.
clean:
	rm -rf dist build client/build _build
