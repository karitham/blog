//// Pure page assembly: `SiteData`/`Post` → full document `Element`.
////
//// No I/O here — `build.gleam` gathers the data, calls these, and
//// writes the result. `site_url` is a plain parameter (never read
//// from the environment) so OG/RSS links are correct both for
//// production and for `BLOG_URL=http://localhost:8000` previews.

import data/model.{type Post, type SiteData}
import encode
import gen/actor/defs.{type ProfileViewDetailed}
import gleam/dict
import gleam/list
import gleam/option.{type Option}
import gleam/string
import hydration.{HydrationModel}
import lustre/attribute.{class, id}
import lustre/element.{type Element, text}
import lustre/element/html.{div, h2}
import plays as plays_view
import profile as profile_view
import repos as repos_view
import view/components/post_view
import view/layout

/// The home page: dynamic sections (profile, music, repos) plus the
/// published article list. `rewrites` is the remote→local image map
/// embedded in the hydration payload for the client's islands.
pub fn index_page(
  data: SiteData,
  site_url: String,
  rewrites: List(#(String, String)),
) -> Element(Nil) {
  let og_image: Option(String) = case data.profile.banner {
    option.Some(img) ->
      option.Some(absolutize_img(img: img, site_url: site_url))
    option.None ->
      option.map(data.profile.avatar, fn(img) {
        absolutize_img(img: img, site_url: site_url)
      })
  }

  let description = case data.profile.description {
    option.Some(desc) -> desc
    option.None -> "Karitham's personal blog and project showcase"
  }

  let model_json =
    encode.encode_hydration_model(HydrationModel(
      profile: data.profile,
      plays: data.recent_plays,
      repos: data.repos,
      rewrites: dict.from_list(rewrites),
    ))

  // The client mounts one island per dynamic section on the ids these
  // render (`#profile-section`, `#plays-rows`, `#repos`) and adopts
  // this markup as its first render.
  let dynamic_sections =
    div([id("dynamic-sections")], [
      profile_view.profile(data.profile),
      plays_view.plays_section(data.recent_plays, data.plays_stats),
      repos_view.repos_section(
        list.map(data.repos, fn(record) { record.value }),
      ),
    ])

  let articles =
    div([class("section")], [
      div([class("section-header")], [
        h2([], [text("Articles")]),
      ]),
      post_view.render_list(data.posts),
    ])

  let meta =
    layout.Meta(
      description: description,
      image: og_image,
      url: site_url <> "/",
      logo: option.map(data.profile.avatar, fn(img) {
        absolutize_img(img: img, site_url: site_url)
      }),
      page_type: layout.Website,
    )

  layout.page(
    site_url: site_url,
    title: "~/kar",
    model_json: model_json,
    content: [dynamic_sections, articles],
    meta: meta,
  )
}

/// A single article page.
pub fn post_page(
  post: Post,
  profile: ProfileViewDetailed,
  site_url: String,
) -> Element(Nil) {
  let slug = model.slug_to_string(post.slug)
  let og_image: Option(String) = case post.image {
    option.None ->
      option.map(profile.avatar, fn(img) {
        absolutize_img(img: img, site_url: site_url)
      })
    option.Some(img) ->
      option.Some(og_image_for_post(slug: slug, img: img, site_url: site_url))
  }

  let meta =
    layout.Meta(
      description: post.description,
      image: og_image,
      url: site_url <> "/posts/" <> slug <> "/",
      logo: profile.avatar,
      page_type: layout.Article(published_time: post.date, tags: post.tags),
    )

  layout.page(
    site_url: site_url,
    title: post.title <> " - Kar",
    model_json: "",
    content: [post_view.render_single(post)],
    meta: meta,
  )
}

// --- helpers ---

/// OG/Twitter image tags must be absolute URLs for crawlers; the
/// mirrored images are root-relative paths. Labels disambiguate the two
/// `String` params.
fn absolutize_img(img img: String, site_url site_url: String) -> String {
  case string.starts_with(img, "/") {
    True -> site_url <> img
    False -> img
  }
}

/// Resolve a post's `image:` frontmatter value to an absolute URL for
/// OG meta. Reuses the same path logic as the article `<img>`. Labels
/// disambiguate the three `String` params.
fn og_image_for_post(
  slug slug: String,
  img img: String,
  site_url site_url: String,
) -> String {
  let path = post_view.resolve_image_url(slug: slug, img: img)
  case string.starts_with(path, "/") {
    True -> site_url <> path
    False -> path
  }
}
