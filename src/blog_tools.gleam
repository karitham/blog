//// CLI subcommands for working with the blog.
////
//// Usage:
////   gleam run                 Build the static site (default)
////   gleam run build           same
////   gleam run client          Build the client JS bundle
////   gleam run new <slug>      Scaffold a new post at priv/posts/<slug>/
////   gleam run help            Print usage
////
//// The SSG and the client build are separate `gleam run` commands
//// because shelling out from Gleam on the BEAM is fragile (the
//// `os:cmd/1` FFI in this OTP version rejects our binary form).
//// For a one-command build, use `make build` which chains them.

import build
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import simplifile

/// Build the static site. Assumes the client JS bundle is already
/// present at `client/build/dev/javascript/karitham_blog_client/`.
/// Use `gleam run client` (or `make build`) to produce that first.
pub fn build_site() {
  let bundle = "client/build/dev/javascript/karitham_blog_client/client.mjs"
  case simplifile.is_file(bundle) {
    Ok(True) -> Nil
    _ -> {
      io.println(
        "Client bundle not found at "
        <> bundle
        <> ". Run `gleam run client` (or `make build`) first.",
      )
      panic as "client bundle missing"
    }
  }
  build.build()
}

/// Print a hint that client building isn't wired into this binary.
/// The real build happens via `cd client && gleam build --target
/// javascript` or `make client`.
pub fn build_client() {
  io.println(
    "Run `cd client && gleam build --target javascript` to build the client.",
  )
  io.println("(Or use `make client` from the project root.)")
  Nil
}

/// Scaffold a new post at `priv/posts/<slug>/index.md` from a
/// template. The input is slugified (lowercased, non-alphanumerics
/// become hyphens, runs of hyphens collapsed) so users can pass
/// whatever feels natural — `just new My new post!` becomes
/// `priv/posts/my-new-post/`. Defaults to `draft: true` so
/// half-written posts don't go live.
pub fn new_post(input: String) {
  let slug = slugify(input)
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
          let content = template(slug)
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

/// Normalize free-form text into a valid slug: lowercase, every
/// non-`[a-z0-9-]` character becomes a hyphen, runs of hyphens
/// collapse to one, leading/trailing hyphens stripped. Returns
/// `""` for input that contains no usable characters.
pub fn slugify(input: String) -> String {
  input
  |> string.lowercase
  |> string.trim
  |> string.to_graphemes
  |> list.map(slugify_char)
  |> string.join("")
  |> collapse_dashes
  |> trim_dashes
}

fn slugify_char(c: String) -> String {
  case c {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z"
    | "0"
    | "1"
    | "2"
    | "3"
    | "4"
    | "5"
    | "6"
    | "7"
    | "8"
    | "9"
    | "-" -> c
    _ -> "-"
  }
}

fn collapse_dashes(s: String) -> String {
  case string.contains(s, "--") {
    True -> collapse_dashes(string.replace(s, each: "--", with: "-"))
    False -> s
  }
}

fn trim_dashes(s: String) -> String {
  case string.starts_with(s, "-") {
    True -> trim_dashes(string.drop_start(s, 1))
    False ->
      case string.ends_with(s, "-") {
        True -> trim_dashes(string.drop_end(s, 1))
        False -> s
      }
  }
}

pub fn print_usage() {
  io.println(
    "Usage:
  gleam run                 Build the static site (alias for `build`)
  gleam run build           Build the static site
  gleam run client          Hint: build the client bundle with make
  gleam run new <slug>      Scaffold a new post at priv/posts/<slug>/
  gleam run help            Show this message

The site is written to ./dist/. The client and SSG are built
separately; for a one-shot build use `make build`.",
  )
}

// --- helpers ---

/// Render the post template for a given slug. Uses today's date
/// so the scaffolded post sorts to the top of the timeline.
fn template(slug: String) -> String {
  let #(y, m, d) = today()
  let date = int.to_string(y) <> "-" <> pad2(m) <> "-" <> pad2(d)
  "---\n"
  <> "title: "
  <> title_from_slug(slug)
  <> "\n"
  <> "description: \n"
  <> "date: "
  <> date
  <> "\n"
  <> "tags: []\n"
  <> "draft: true\n"
  <> "---\n"
  <> "\n"
  <> "Write your post here.\n"
}

fn title_from_slug(slug: String) -> String {
  // "hello-world" -> "Hello World". Best-effort — the user will
  // overwrite the title anyway once they start writing.
  slug
  |> string.split(on: "-")
  |> list.map(capitalize)
  |> string.join(" ")
}

fn capitalize(word: String) -> String {
  case string.to_graphemes(word) {
    [] -> ""
    [first, ..rest] -> string.uppercase(first) <> string.join(rest, "")
  }
}

fn pad2(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}

@external(erlang, "erlang", "date")
fn erlang_date() -> #(Int, Int, Int)

fn today() -> #(Int, Int, Int) {
  erlang_date()
}
