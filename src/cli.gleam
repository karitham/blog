//// CLI subcommands for working with the blog — the impure shell.
////
//// Usage:
////   gleam run                 Build the static site (default)
////   gleam run build           same
////   gleam run new <slug>      Scaffold a new post at priv/posts/<slug>/
////   gleam run help            Print usage
////
//// The pure helpers (slugify, template) live in `cli/slug` and
//// `cli/template`; this module does the filesystem work and panics.
//// The SSG and the client build are separate `gleam run` commands
//// because shelling out from Gleam on the BEAM is fragile (the
//// `os:cmd/1` FFI in this OTP version rejects our binary form).
//// For a one-command build, use `make build` which chains them.

import build
import cli/slug
import cli/template
import gleam/io
import gleam/string
import simplifile

/// Build the static site. Assumes the client JS bundle is already
/// present at `client/build/dev/javascript/karitham_blog_client/`.
/// Use `make build` to produce that first.
pub fn build_site() {
  let bundle = "client/build/dev/javascript/karitham_blog_client/client.mjs"
  case simplifile.is_file(bundle) {
    Ok(True) -> Nil
    _ -> {
      io.println(
        "Client bundle not found at "
        <> bundle
        <> ". Run `make build` (or `cd client && gleam build --target javascript`) first.",
      )
      panic as "client bundle missing"
    }
  }
  build.build()
}

/// Scaffold a new post at `priv/posts/<slug>/index.md` from a
/// template. The input is slugified (lowercased, non-alphanumerics
/// become hyphens, runs of hyphens collapsed) so users can pass
/// whatever feels natural — `just new My new post!` becomes
/// `priv/posts/my-new-post/`. Defaults to `draft: true` so
/// half-written posts don't go live.
pub fn new_post(input: String) {
  let slug = slug.slugify(input)
  case slug {
    "" -> {
      io.println(
        "Error: \""
        <> input
        <> "\" doesn't contain any valid slug characters (letters, digits, hyphens).",
      )
      panic as "empty slug"
    }
    _ -> {
      let dir = "priv/posts/" <> slug
      let path = dir <> "/index.md"
      case simplifile.is_directory(dir) {
        Ok(True) -> {
          io.println("Error: " <> dir <> " already exists.")
          panic as "post already exists"
        }
        _ -> {
          let _ = simplifile.create_directory_all(dir)
          let content = template.template(slug, today())
          case simplifile.write(to: path, contents: content) {
            Ok(_) -> {
              io.println("Created " <> path)
              io.println("Edit the post, then remove `draft: true` to publish.")
            }
            Error(e) -> {
              io.println(
                "Failed to write " <> path <> ": " <> string.inspect(e),
              )
              panic as "post write failed"
            }
          }
        }
      }
    }
  }
}

pub fn print_usage() {
  io.println(
    "Usage:
  gleam run                 Build the static site (alias for `build`)
  gleam run build           Build the static site
  gleam run new <slug>      Scaffold a new post at priv/posts/<slug>/
  gleam run help            Show this message

The site is written to ./dist/. The client and SSG are built
separately; for a one-shot build use `make build`.",
  )
}

// --- helpers ---

@external(erlang, "erlang", "date")
fn erlang_date() -> #(Int, Int, Int)

fn today() -> #(Int, Int, Int) {
  erlang_date()
}
