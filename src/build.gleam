//// The build pipeline's commit shell: gather → render → write.
////
//// Data fetching lives in `data/sources` + `data/transport`, image
//// mirroring in `data/images`, and pure page assembly in
//// `render/page`. This module only wires them together and performs
//// the filesystem writes — no business logic of its own.

import config
import data/images
import data/model.{type Post, type SiteData, SiteData}
import data/sources
import data/transport
import gen/actor/defs.{type ProfileViewDetailed}
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import lustre/element.{type Element}
import render/page
import simplifile
import view/layout

const client_bundle_src = "client/dist/karitham_blog_client.js"

/// The bundle path must exist before the (slow, network-bound) data
/// fetches run — a site that silently builds without its client JS is
/// worse than a failed build.
fn ensure_client_bundle() -> Result(Nil, String) {
  case simplifile.is_file(client_bundle_src) {
    Ok(True) -> Ok(Nil)
    _ -> {
      let msg =
        "Client bundle not found at "
        <> client_bundle_src
        <> ". Run `just client` (or `cd client && gleam run -m lustre/dev build --minify=true --no-html=true`) first."
      io.println(msg)
      Error("client bundle missing: " <> client_bundle_src)
    }
  }
}

pub fn build() -> Result(Nil, String) {
  case ensure_client_bundle() {
    Error(e) -> Error(e)
    Ok(Nil) -> {
      let cfg = config.read_env()

      io.println("Fetching data...")
      case sources.fetch_all(transport.fetch_body) {
        Error(e) -> {
          io.println("Build failed: " <> e)
          Error(e)
        }
        Ok(site_data) ->
          case do_build(site_data, cfg) {
            Ok(Nil) -> Ok(Nil)
            Error(e) -> {
              io.println("Build failed: " <> e)
              Error(e)
            }
          }
      }
    }
  }
}

fn do_build(
  site_data: SiteData,
  cfg: config.SiteConfig,
) -> Result(Nil, String) {
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
  use _ <- result.try(
    create_dir(cfg.dist_dir)
    |> result.map_error(fn(e) {
      "mkdir " <> cfg.dist_dir <> ": " <> string.inspect(e)
    }),
  )

  let published_data = SiteData(..site_data, posts: published)

  let index_html =
    page.index_page(published_data, cfg.site_url, profile_images.rewrites)
    |> render_document
  write_text(path: cfg.dist_dir <> "/index.html", contents: index_html)

  use _ <- result.try(write_posts(published, published_data.profile, cfg))
  use _ <- result.try(write_posts(drafts, published_data.profile, cfg))

  write_style(cfg)
  write_highlight(cfg)

  let rss = layout.rss_feed(published, cfg.site_url)
  write_text(path: cfg.dist_dir <> "/rss.xml", contents: rss)

  copy_post_assets(published, cfg)
  copy_post_assets(drafts, cfg)
  copy_favicons(cfg)
  use _ <- result.try(copy_image_cache(cfg))
  use _ <- result.try(copy_client_bundle(cfg))

  io.println("Done! Site generated in " <> cfg.dist_dir)
  Ok(Nil)
}

fn log_draft(post: Post) -> Nil {
  io.println(
    "  [draft] " <> model.slug_to_string(post.slug) <> " — " <> post.title,
  )
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
) -> Result(Nil, String) {
  list.try_map(posts, fn(post) {
    let slug = model.slug_to_string(post.slug)
    let dir = cfg.dist_dir <> "/posts/" <> slug
    use _ <- result.try(
      create_dir(dir)
      |> result.map_error(fn(e) { "mkdir " <> dir <> ": " <> string.inspect(e) }),
    )
    let html = page.post_page(post, profile, cfg.site_url) |> render_document
    let path = dir <> "/index.html"
    write_text(path: path, contents: html)
    io.println("  wrote " <> path)
    Ok(Nil)
  })
  |> result.map(fn(_) { Nil })
}

fn write_style(cfg: config.SiteConfig) {
  // CSS lives as a real file at priv/static/style.css so it gets
  // editor highlighting and treefmt. Build just copies it.
  case simplifile.read("priv/static/style.css") {
    Ok(contents) -> {
      let path = cfg.dist_dir <> "/style.css"
      write_text(path: path, contents: contents)
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
        write_text(path: dst, contents: contents)
        io.println("  wrote " <> dst)
      }
      Error(e) -> log_io_error(op: "read", path: src, error: e)
    }
  })
}

/// Copy every non-`index.md` file under each post's directory to
/// `dist/posts/<slug>/` (including drafts — same preview rationale as
/// the draft pages themselves). Files inside subdirectories are
/// skipped; only flat assets are deployed.
fn copy_post_assets(posts: List(Post), cfg: config.SiteConfig) {
  list.each(posts, fn(post) {
    let slug = model.slug_to_string(post.slug)
    copy_post_files(
      src_dir: "priv/posts/" <> slug,
      dst_dir: cfg.dist_dir <> "/posts/" <> slug,
    )
  })
}

fn copy_post_files(src_dir src_dir: String, dst_dir dst_dir: String) -> Nil {
  case simplifile.read_directory(src_dir) {
    Ok(entries) ->
      list.each(entries, fn(entry) {
        let src = src_dir <> "/" <> entry
        let dst = dst_dir <> "/" <> entry
        case entry, simplifile.is_directory(src) {
          "index.md", _ -> Nil
          _, Ok(True) -> Nil
          _, _ -> copy_file_bits(src: src, dst: dst)
        }
      })
    Error(e) -> log_io_error(op: "read", path: src_dir, error: e)
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
    copy_file_bits(src: src, dst: dst)
  })
}

/// Copy the client bundle produced by `just client` (a single
/// self-executing ES module) into the site. Existence is already
/// enforced by `ensure_client_bundle` before the build starts.
fn copy_client_bundle(cfg: config.SiteConfig) -> Result(Nil, String) {
  // Delete first so a whitelisted dev tree from an older build
  // can't linger next to the bundle.
  let _ = simplifile.delete(cfg.dist_dir <> "/client")
  use _ <- result.try(
    create_dir(cfg.dist_dir <> "/client")
    |> result.map_error(fn(e) {
      "mkdir " <> cfg.dist_dir <> "/client: " <> string.inspect(e)
    }),
  )
  copy_file_bits(
    src: client_bundle_src,
    dst: cfg.dist_dir <> "/client/karitham_blog_client.js",
  )
  io.println("  copied client bundle")
  Ok(Nil)
}

/// Copy the mirrored cover/artist images from the refresh cache into
/// the site so the browser serves them locally instead of hitting
/// Cover Art Archive / Wikimedia at page load. No-op without a cache.
/// Logs `is_directory` errors for diagnostics but does not fail the build.
fn copy_image_cache(cfg: config.SiteConfig) -> Result(Nil, String) {
  case simplifile.is_directory("priv/cache/img") {
    Ok(True) -> copy_dir(src: "priv/cache/img", dst: cfg.dist_dir <> "/img")
    Ok(False) -> Ok(Nil)
    Error(e) -> {
      log_io_error(op: "is_dir", path: "priv/cache/img", error: e)
      Ok(Nil)
    }
  }
}

fn copy_dir(src src: String, dst dst: String) -> Result(Nil, String) {
  use _ <- result.try(
    create_dir(dst)
    |> result.map_error(fn(e) { "mkdir " <> dst <> ": " <> string.inspect(e) }),
  )
  case simplifile.read_directory(src) {
    Ok(entries) -> {
      case
        list.try_map(entries, fn(entry) {
          // `.erl` files and `_gleam_artefacts` are Erlang-target build
          // leftovers that leak into the JS dev tree; the browser never
          // imports them, so skip them.
          case entry {
            "_gleam_artefacts" -> Ok(Nil)
            e ->
              case string.ends_with(e, ".erl") {
                True -> Ok(Nil)
                False -> {
                  let src_path = src <> "/" <> e
                  let dst_path = dst <> "/" <> e
                  case simplifile.is_directory(src_path) {
                    Ok(True) -> copy_dir(src: src_path, dst: dst_path)
                    _ -> {
                      copy_file_bits(src: src_path, dst: dst_path)
                      Ok(Nil)
                    }
                  }
                }
              }
          }
        })
      {
        Ok(_) -> Ok(Nil)
        Error(e) -> Error(e)
      }
    }
    Error(e) -> {
      log_io_error(op: "read", path: src, error: e)
      Error("read " <> src <> ": " <> string.inspect(e))
    }
  }
}

// --- I/O helpers that log errors instead of silently swallowing them ---

fn render_document(element: Element(Nil)) -> String {
  element.to_document_string(element)
}

fn write_text(path path: String, contents contents: String) -> Nil {
  case simplifile.write(to: path, contents: contents) {
    Ok(Nil) -> Nil
    Error(e) -> log_io_error(op: "write", path: path, error: e)
  }
}

fn copy_file_bits(src src: String, dst dst: String) -> Nil {
  case simplifile.read_bits(src) {
    Ok(contents) ->
      case simplifile.write_bits(to: dst, bits: contents) {
        Ok(Nil) -> Nil
        Error(e) -> log_io_error(op: "write", path: dst, error: e)
      }
    Error(e) -> log_io_error(op: "read", path: src, error: e)
  }
}

fn create_dir(path: String) -> Result(Nil, simplifile.FileError) {
  case simplifile.create_directory_all(path) {
    Ok(_) -> Ok(Nil)
    Error(e) -> {
      log_io_error(op: "mkdir", path: path, error: e)
      Error(e)
    }
  }
}

fn log_io_error(
  op op: String,
  path path: String,
  error error: simplifile.FileError,
) -> Nil {
  io.println(
    "  " <> op <> " failed for " <> path <> ": " <> string.inspect(error),
  )
}
