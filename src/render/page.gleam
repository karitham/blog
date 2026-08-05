//// Pure page assembly: `SiteData`/`Post` → full document `Element`.
////
//// No I/O here — `build.gleam` gathers the data, calls these, and
//// writes the result. `site_url` is a plain parameter (never read
//// from the environment) so OG/RSS links are correct both for
//// production and for `BLOG_URL=http://localhost:8000` previews.

import data/model.{type Post, type SiteData}
import dynamic
import encode
import gen/actor/defs.{type ProfileViewDetailed}
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some, map as option_map}
import gleam/string
import hydration.{HydrationModel}
import lustre/attribute.{class, id, type_}
import lustre/element.{type Element, fragment, text}
import lustre/element/html.{div, h2, script}
import view/components/post_view
import view/layout

/// The home page: dynamic sections (profile, music, repos) plus the
/// published article list. `rewrites` is the remote→local image map
/// embedded for the client's hydration pass.
pub fn index_page(
  data: SiteData,
  site_url: String,
  rewrites: List(#(String, String)),
) -> Element(Nil) {
  let og_image: Option(String) = case data.profile.banner {
    Some(img) -> Some(absolutize_img(img, site_url))
    None ->
      option_map(data.profile.avatar, fn(img) { absolutize_img(img, site_url) })
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

  let dynamic_sections =
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
      dynamic_sections,
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
      url: site_url <> "/",
      logo: option_map(data.profile.avatar, fn(img) {
        absolutize_img(img, site_url)
      }),
      page_type: layout.Website,
    )

  layout.page("~/kar", site_url, model_json, content, meta)
}

/// A single article page.
pub fn post_page(
  post: Post,
  profile: ProfileViewDetailed,
  site_url: String,
) -> Element(Nil) {
  let og_image: Option(String) = case post.image {
    "" -> option_map(profile.avatar, fn(img) { absolutize_img(img, site_url) })
    img -> Some(og_image_for_post(post.slug, img, site_url))
  }

  let meta =
    layout.Meta(
      description: post.description,
      image: og_image,
      url: site_url <> "/posts/" <> post.slug <> "/",
      logo: profile.avatar,
      page_type: layout.Article(published_time: post.date, tags: post.tags),
    )

  layout.page(
    post.title <> " - Kar",
    site_url,
    "",
    post_view.render_single(post),
    meta,
  )
}

// --- helpers ---

/// OG/Twitter image tags must be absolute URLs for crawlers; the
/// mirrored images are root-relative paths.
fn absolutize_img(img: String, site_url: String) -> String {
  case string.starts_with(img, "/") {
    True -> site_url <> img
    False -> img
  }
}

/// Resolve a post's `image:` frontmatter value to an absolute URL for
/// OG meta. Reuses the same path logic as the article `<img>`.
fn og_image_for_post(slug: String, img: String, site_url: String) -> String {
  let path = post_view.resolve_image_url(slug, img)
  case string.starts_with(path, "/") {
    True -> site_url <> path
    False -> path
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
