import api
import data/fetch
import data/images
import data/model.{type Post, type SiteData, SiteData}
import dynamic
import encode
import filepath
import gen/actor/defs.{type ProfileViewDetailed}
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some, map as option_map}
import gleam/result
import gleam/string
import hydration.{HydrationModel}
import lustre/attribute.{class, id, type_}
import lustre/element.{type Element, fragment, text, to_document_string}
import lustre/element/html.{div, h2, script}
import simplifile
import view/components/post_view
import view/layout

const dist_dir = "./dist"

fn render_document(element: Element(Nil)) -> String {
  element
  |> to_document_string
  |> dynamic.strip_fragment_comments
}

pub fn build() {
  io.println("Fetching data...")
  let site_data = fetch.fetch_all()

  // Mirror the profile's avatar/banner blobs into the site so the
  // browser never hits the PDS for them; the returned profile points
  // at the local copies and `rewrites` lets the client do the same.
  let profile_images = images.mirror_profile_images(site_data.profile)
  let site_data = SiteData(..site_data, profile: profile_images.profile)

  // Drafts are excluded from the SSG output but the user should
  // know they exist (so they don't lose work or wonder where
  // their post went).
  let #(drafts, published) = list.partition(site_data.posts, fn(p) { p.draft })
  list.each(drafts, log_draft)

  io.println("Generating site...")
  let _ = create_dir(dist_dir)

  let published_data = SiteData(..site_data, posts: published)

  write_index(published_data, profile_images.rewrites)
  write_posts(published, published_data.profile)
  write_posts(drafts, published_data.profile)
  write_style()
  write_highlight()
  write_rss(published)
  copy_post_assets(published)
  copy_post_assets(drafts)
  copy_favicons()
  copy_image_cache()
  copy_client_js()

  io.println("Done! Site generated in " <> dist_dir)
}

fn log_draft(post: Post) -> Nil {
  io.println("  [draft] " <> post.slug <> " — " <> post.title)
}

fn write_index(data: SiteData, rewrites: List(#(String, String))) {
  let og_image: Option(String) = case data.profile.banner {
    Some(img) -> Some(absolutize_img(img))
    None -> option_map(data.profile.avatar, absolutize_img)
  }

  let description = case data.profile.description {
    Some(desc) -> desc
    None -> "Karitham's personal blog and project showcase"
  }

  let model_json =
    encode.encode_hydration_model(HydrationModel(
      profile: data.profile,
      plays: data.recent_plays,
      repos: data.repos,
    ))

  let dynamic =
    div([id("dynamic-sections")], [
      dynamic.dynamic_sections(
        data.profile,
        data.recent_plays,
        data.plays_stats,
        list.map(data.repos, fn(record) { record.value }),
      ),
    ])

  // The client re-fetches the profile on page load and re-renders it
  // with the PDS's remote avatar/banner URLs; this map lets it point
  // those at the local mirrors instead.
  let rewrites_script =
    script(
      [type_("application/json"), id("image-rewrites")],
      encode_rewrites(rewrites),
    )

  let content =
    fragment([
      rewrites_script,
      dynamic,
      div([class("section")], [
        div([class("section-header")], [
          h2([], [text("Articles")]),
        ]),
        post_view.render_list(data.posts),
      ]),
    ])

  let meta =
    layout.Meta(
      description: description,
      image: og_image,
      url: api.site_url() <> "/",
      logo: option_map(data.profile.avatar, absolutize_img),
      page_type: layout.Website,
    )

  let html = layout.page("~/kar", model_json, content, meta) |> render_document
  let path = dist_dir <> "/index.html"
  write_text(path, html)
  io.println("  wrote " <> path)
}

fn write_posts(posts: List(Post), profile: ProfileViewDetailed) {
  list.each(posts, fn(post) { write_single_post(post, profile) })
}

fn write_single_post(post: Post, profile: ProfileViewDetailed) {
  let dir = dist_dir <> "/posts/" <> post.slug
  let _ = create_dir(dir)

  let title = post.title <> " - Kar"
  let og_image: Option(String) = case post.image {
    "" -> option_map(profile.avatar, absolutize_img)
    img -> Some(resolve_og_image_url(post.slug, img))
  }

  let meta =
    layout.Meta(
      description: post.description,
      image: og_image,
      url: api.site_url() <> "/posts/" <> post.slug <> "/",
      logo: profile.avatar,
      page_type: layout.Article(published_time: post.date, tags: post.tags),
    )

  let html =
    layout.page(title, "", post_view.render_single(post), meta)
    |> render_document
  let path = dir <> "/index.html"
  write_text(path, html)
  io.println("  wrote " <> path)
}

fn write_style() {
  // CSS lives as a real file at priv/static/style.css so it gets
  // editor highlighting and treefmt. Build just copies it.
  case simplifile.read("priv/static/style.css") {
    Ok(contents) -> {
      let path = dist_dir <> "/style.css"
      write_text(path, contents)
      io.println("  wrote " <> path)
    }
    Error(_) -> io.println("  priv/static/style.css missing — skipping")
  }
}

fn write_highlight() {
  // Vendored highlight.js + a small init module that registers
  // gleam + nushell grammars. Served as static files.
  let files = [
    #("priv/static/highlight.min.js", dist_dir <> "/highlight.min.js"),
    #("priv/static/highlight.mjs", dist_dir <> "/highlight.mjs"),
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

fn write_rss(posts: List(Post)) {
  let items =
    list.map(posts, fn(p) { #(p.title, p.description, p.slug, p.date) })
  let rss = layout.rss_feed(items)
  let path = dist_dir <> "/rss.xml"
  write_text(path, rss)
  io.println("  wrote " <> path)
}

/// Copy every non-`index.md` file under each *published* post's
/// directory to `dist/posts/<slug>/`. Drafts' assets are not
/// deployed — the build pipeline filters drafts out before
/// calling this, so we just walk the list we were given.
fn copy_post_assets(posts: List(Post)) {
  list.each(posts, fn(post) {
    copy_post_files(
      "priv/posts/" <> post.slug,
      dist_dir <> "/posts/" <> post.slug,
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

fn copy_favicons() {
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
    let dst = dist_dir <> "/" <> name
    copy_file_bits(src, dst)
  })
}

fn copy_client_js() {
  let src = "client/build/dev/javascript"
  let dst = dist_dir <> "/client"

  case simplifile.is_directory(src) {
    Ok(True) -> {
      let _ = create_dir(dst)
      copy_dir(src, dst)
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
fn copy_image_cache() {
  case simplifile.is_directory("priv/cache/img") {
    Ok(True) -> copy_dir("priv/cache/img", dist_dir <> "/img")
    _ -> Nil
  }
}

/// The remote→local rewrite map as a JSON object, embedded in
/// `#image-rewrites` for the client (client/browser_ffi.mjs).
fn encode_rewrites(rewrites: List(#(String, String))) -> String {
  rewrites
  |> list.map(fn(pair) {
    let #(remote, local) = pair
    #(remote, json.string(local))
  })
  |> json.object
  |> json.to_string
}

/// OG/Twitter image tags must be absolute URLs for crawlers; the
/// mirrored images are root-relative paths.
fn absolutize_img(img: String) -> String {
  case string.starts_with(img, "/") {
    True -> api.site_url() <> img
    False -> img
  }
}

fn resolve_og_image_url(slug: String, img: String) -> String {
  case
    string.starts_with(img, "http://") || string.starts_with(img, "https://")
  {
    True -> img
    False -> {
      let expanded = filepath.expand(img) |> result.unwrap(img)
      case filepath.is_absolute(expanded) {
        True -> api.site_url() <> expanded
        False ->
          api.site_url()
          <> filepath.join(filepath.join("/posts", slug), expanded)
      }
    }
  }
}

fn copy_dir(src: String, dst: String) -> Nil {
  case simplifile.read_directory(src) {
    Ok(entries) ->
      list.each(entries, fn(entry) {
        let src_path = src <> "/" <> entry
        let dst_path = dst <> "/" <> entry
        case simplifile.is_directory(src_path) {
          Ok(True) -> {
            let _ = create_dir(dst_path)
            copy_dir(src_path, dst_path)
          }
          _ -> copy_file_bits(src_path, dst_path)
        }
      })
    Error(_) -> Nil
  }
}

// --- I/O helpers that log errors instead of silently swallowing them ---

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
