//// The build pipeline's commit shell: gather → render → write.
////
//// Data fetching lives in `data/sources` + `data/transport`, image
//// mirroring in `data/images`, and pure page assembly in
//// `render/page`. This module only wires them together and performs
//// the filesystem writes — no business logic of its own.

import config
import data/images
import data/model.{type Post, SiteData}
import data/sources
import data/transport
import dynamic
import gen/actor/defs.{type ProfileViewDetailed}
import gleam/io
import gleam/list
import gleam/string
import lustre/element.{type Element, to_document_string}
import render/page
import simplifile
import view/layout

pub fn build() {
  let cfg = config.read_env()

  io.println("Fetching data...")
  let site_data = sources.fetch_all(transport.fetch_body)

  // Mirror the profile's avatar/banner blobs into the site so the
  // browser never hits the PDS for them; the returned profile points
  // at the local copies and `rewrites` lets the client do the same.
  let profile_images =
    images.mirror_profile_images(
      site_data.profile,
      transport.fetch_image,
      write_bits,
    )
  let site_data = SiteData(..site_data, profile: profile_images.profile)

  // Drafts ARE built into dist/ so a half-written post is reachable
  // by URL for preview. They're deliberately excluded from the index
  // and the RSS feed, so nothing links to them from the home page —
  // a direct URL is the only way in. Don't "fix" the copy below to
  // skip drafts; that would break the preview flow.
  let #(drafts, published) = list.partition(site_data.posts, fn(p) { p.draft })
  list.each(drafts, log_draft)

  io.println("Generating site...")
  let _ = create_dir(cfg.dist_dir)

  let published_data = SiteData(..site_data, posts: published)

  let index_html =
    page.index_page(published_data, cfg.site_url, profile_images.rewrites)
    |> render_document
  write_text(cfg.dist_dir <> "/index.html", index_html)

  write_posts(published, published_data.profile, cfg)
  write_posts(drafts, published_data.profile, cfg)

  write_style(cfg)
  write_highlight(cfg)

  let rss = layout.rss_feed(published, cfg.site_url)
  write_text(cfg.dist_dir <> "/rss.xml", rss)

  copy_post_assets(published, cfg)
  copy_post_assets(drafts, cfg)
  copy_favicons(cfg)
  copy_image_cache(cfg)
  copy_client_js(cfg)

  io.println("Done! Site generated in " <> cfg.dist_dir)
}

fn log_draft(post: Post) -> Nil {
  io.println("  [draft] " <> post.slug <> " — " <> post.title)
}

/// simplifile's write_bits has labeled arguments; this unlabeled
/// wrapper matches `images.WriteBits` for injection.
fn write_bits(
  path: String,
  bits: BitArray,
) -> Result(Nil, simplifile.FileError) {
  simplifile.write_bits(to: path, bits: bits)
}

fn write_posts(
  posts: List(Post),
  profile: ProfileViewDetailed,
  cfg: config.SiteConfig,
) {
  list.each(posts, fn(post) {
    let dir = cfg.dist_dir <> "/posts/" <> post.slug
    let _ = create_dir(dir)
    let html = page.post_page(post, profile, cfg.site_url) |> render_document
    let path = dir <> "/index.html"
    write_text(path, html)
    io.println("  wrote " <> path)
  })
}

fn write_style(cfg: config.SiteConfig) {
  // CSS lives as a real file at priv/static/style.css so it gets
  // editor highlighting and treefmt. Build just copies it.
  case simplifile.read("priv/static/style.css") {
    Ok(contents) -> {
      let path = cfg.dist_dir <> "/style.css"
      write_text(path, contents)
      io.println("  wrote " <> path)
    }
    Error(_) -> io.println("  priv/static/style.css missing — skipping")
  }
}

fn write_highlight(cfg: config.SiteConfig) {
  // Vendored highlight.js + a small init module that registers
  // gleam + nushell grammars. Served as static files.
  let files = [
    #("priv/static/highlight.min.js", cfg.dist_dir <> "/highlight.min.js"),
    #("priv/static/highlight.mjs", cfg.dist_dir <> "/highlight.mjs"),
  ]
  list.each(files, fn(pair) {
    let #(src, dst) = pair
    case simplifile.read(src) {
      Ok(contents) -> {
        write_text(dst, contents)
        io.println("  wrote " <> dst)
      }
      Error(_) -> Nil
    }
  })
}

/// Copy every non-`index.md` file under each post's directory to
/// `dist/posts/<slug>/` (including drafts — same preview rationale as
/// the draft pages themselves). Files inside subdirectories are
/// skipped; only flat assets are deployed.
fn copy_post_assets(posts: List(Post), cfg: config.SiteConfig) {
  list.each(posts, fn(post) {
    copy_post_files(
      "priv/posts/" <> post.slug,
      cfg.dist_dir <> "/posts/" <> post.slug,
    )
  })
}

fn copy_post_files(src_dir: String, dst_dir: String) -> Nil {
  case simplifile.read_directory(src_dir) {
    Ok(entries) ->
      list.each(entries, fn(entry) {
        let src = src_dir <> "/" <> entry
        let dst = dst_dir <> "/" <> entry
        case entry, simplifile.is_directory(src) {
          "index.md", _ -> Nil
          _, Ok(True) -> Nil
          _, _ -> copy_file_bits(src, dst)
        }
      })
    Error(_) -> Nil
  }
}

fn copy_favicons(cfg: config.SiteConfig) {
  let favicons = [
    "favicon-32x32.png",
    "favicon-16x16.png",
    "apple-touch-icon.png",
    "android-chrome-192x192.png",
    "android-chrome-512x512.png",
    "site.webmanifest",
  ]
  list.each(favicons, fn(name) {
    let src = "priv/static/icons/" <> name
    let dst = cfg.dist_dir <> "/" <> name
    copy_file_bits(src, dst)
  })
}

/// The top-level packages the compiled client bundle actually imports
/// (traced from `karitham_blog_client/*.mjs` and their transitive
/// imports). The full dev tree also contains test runners (gleeunit),
/// Erlang artefacts, and unused packages (atproto_client, kryptos,
/// gose, bigi, exception, houdini, gleam_otp, gleam_erlang,
/// gleam_http, gleam_crypto, fingerprint) — copying those would bloat
/// `dist/client` by ~12 MB for nothing.
const client_keep = [
  "prelude.mjs",
  "karitham_blog_client",
  "shared",
  "gleam_stdlib",
  "gleam_json",
  "gleam_time",
  "lustre",
]

fn copy_client_js(cfg: config.SiteConfig) {
  let src = "client/build/dev/javascript"
  let dst = cfg.dist_dir <> "/client"

  case simplifile.is_directory(src) {
    Ok(True) -> {
      // A previous build may have copied the full dev tree here;
      // delete first so stale packages don't linger under the
      // whitelist.
      let _ = simplifile.delete(dst)
      let _ = create_dir(dst)
      list.each(client_keep, fn(entry) {
        let src_path = src <> "/" <> entry
        let dst_path = dst <> "/" <> entry
        case simplifile.is_directory(src_path) {
          Ok(True) -> copy_dir(src_path, dst_path)
          _ -> copy_file_bits(src_path, dst_path)
        }
      })
      io.println("  copied client JS")
    }
    _ ->
      io.println(
        "  client JS not built — skip 'cd client && gleam build' first",
      )
  }
}

/// Copy the mirrored cover/artist images from the refresh cache into
/// the site so the browser serves them locally instead of hitting
/// Cover Art Archive / Wikimedia at page load. No-op without a cache.
fn copy_image_cache(cfg: config.SiteConfig) {
  case simplifile.is_directory("priv/cache/img") {
    Ok(True) -> copy_dir("priv/cache/img", cfg.dist_dir <> "/img")
    _ -> Nil
  }
}

fn copy_dir(src: String, dst: String) -> Nil {
  let _ = create_dir(dst)
  case simplifile.read_directory(src) {
    Ok(entries) ->
      list.each(entries, fn(entry) {
        // `.erl` files and `_gleam_artefacts` are Erlang-target build
        // leftovers that leak into the JS dev tree; the browser never
        // imports them, so skip them.
        case entry {
          "_gleam_artefacts" -> Nil
          e ->
            case string.ends_with(e, ".erl") {
              True -> Nil
              False -> {
                let src_path = src <> "/" <> e
                let dst_path = dst <> "/" <> e
                case simplifile.is_directory(src_path) {
                  Ok(True) -> copy_dir(src_path, dst_path)
                  _ -> copy_file_bits(src_path, dst_path)
                }
              }
            }
        }
      })
    Error(_) -> Nil
  }
}

// --- I/O helpers that log errors instead of silently swallowing them ---

fn render_document(element: Element(Nil)) -> String {
  element
  |> to_document_string
  |> dynamic.strip_fragment_comments
}

fn write_text(path: String, contents: String) -> Nil {
  case simplifile.write(to: path, contents: contents) {
    Ok(Nil) -> Nil
    Error(e) -> log_io_error("write", path, e)
  }
}

fn copy_file_bits(src: String, dst: String) -> Nil {
  case simplifile.read_bits(src) {
    Ok(contents) ->
      case simplifile.write_bits(to: dst, bits: contents) {
        Ok(Nil) -> Nil
        Error(e) -> log_io_error("write", dst, e)
      }
    Error(_) -> Nil
  }
}

fn create_dir(path: String) -> Result(Nil, simplifile.FileError) {
  case simplifile.create_directory_all(path) {
    Ok(_) -> Ok(Nil)
    Error(e) -> {
      log_io_error("mkdir", path, e)
      Error(e)
    }
  }
}

fn log_io_error(op: String, path: String, e: simplifile.FileError) -> Nil {
  io.println("  " <> op <> " failed for " <> path <> ": " <> string.inspect(e))
}
