//// Post scaffolding and usage text.
////
//// Usage:
////   gleam run                 Build the static site (default)
////   gleam run build           same
////   gleam run new <slug>      Scaffold a new post at priv/posts/<slug>/
////   gleam run help            Print usage
////
//// The build subcommand dispatches straight to `build.build()`. The
//// pure helpers (slugify, template) live in `cli/slug` and
//// `cli/template`; this module does the filesystem work and panics.

import cli/slug
import cli/template
import gleam/io
import gleam/string
import simplifile

/// Scaffold a new post at `priv/posts/<slug>/index.md` from a
/// template. The input is slugified (lowercased, non-alphanumerics
/// become hyphens, runs of hyphens collapsed) so users can pass
/// whatever feels natural — `just new My new post!` becomes
/// `priv/posts/my-new-post/`. Defaults to `draft: true` so
/// half-written posts don't go live. Returns `Error` on bad input
/// or filesystem failure; the CLI entry point logs and exits.
pub fn new_post(input: String) -> Result(Nil, String) {
  let slug = slug.slugify(input)
  case slug {
    "" -> {
      let msg =
        "Error: \""
        <> input
        <> "\" doesn't contain any valid slug characters (letters, digits, hyphens)."
      io.println(msg)
      Error("empty slug from: " <> input)
    }
    _ -> {
      let dir = "priv/posts/" <> slug
      let path = dir <> "/index.md"
      case simplifile.is_directory(dir) {
        Ok(True) -> {
          let msg = "Error: " <> dir <> " already exists."
          io.println(msg)
          Error("post already exists: " <> dir)
        }
        _ -> {
          case simplifile.create_directory_all(dir) {
            Ok(_) -> Nil
            Error(e) -> {
              let msg = "Failed to mkdir " <> dir <> ": " <> string.inspect(e)
              io.println(msg)
            }
          }
          let content = template.template(slug, today())
          case simplifile.write(to: path, contents: content) {
            Ok(_) -> {
              io.println("Created " <> path)
              io.println("Edit the post, then remove `draft: true` to publish.")
              Ok(Nil)
            }
            Error(e) -> {
              let msg = "Failed to write " <> path <> ": " <> string.inspect(e)
              io.println(msg)
              Error(msg)
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
separately; for a one-shot build use `just build`.",
  )
}

// --- helpers ---

@external(erlang, "erlang", "date")
fn erlang_date() -> #(Int, Int, Int)

fn today() -> #(Int, Int, Int) {
  erlang_date()
}
