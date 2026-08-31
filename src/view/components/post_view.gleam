//// Post view: card list and single article page.
//// Pure — no I/O, no config reads.

import card
import data/model.{type Post}
import date
import filepath
import gleam/list
import gleam/option
import gleam/string
import lustre/attribute.{alt, class, src}
import lustre/element.{type Element, none, text, unsafe_raw_html}
import lustre/element/html.{div, h1, img, p, span}

/// Render the article card list for the index page.
pub fn render_list(posts: List(Post)) -> Element(Nil) {
  case posts {
    [] -> p([], [text("No articles yet.")])
    _ -> div([], list.map(posts, render_article_card))
  }
}

fn render_article_card(post: Post) -> Element(Nil) {
  let slug = model.slug_to_string(post.slug)
  card.card(
    title_href: "/posts/" <> slug <> "/",
    title_text: post.title,
    title_target: option.None,
    date: date.format_ymd(post.date),
    description: post.description,
    topics: post.tags,
  )
}

/// Render a single article page.
pub fn render_single(post: Post) -> Element(Nil) {
  let hero_image = case post.image {
    option.None -> none()
    option.Some(image_path) -> {
      let slug = model.slug_to_string(post.slug)
      let image_src = resolve_image_url(slug: slug, img: image_path)
      div([class("hero-image")], [
        img([src(image_src), alt(post.title)]),
      ])
    }
  }

  let tags = case post.tags {
    [] -> none()
    ts ->
      div(
        [class("tags")],
        list.map(ts, fn(t) { span([class("emph")], [text(t)]) }),
      )
  }

  div([class("post")], [
    hero_image,
    h1([], [text(post.title)]),
    div([class("post-meta")], [
      span([], [
        text("Written "),
        span([class("emph")], [text(date.format_ymd(post.date))]),
      ]),
      tags,
    ]),
    div([class("post-content")], [unsafe_raw_html("", "div", [], post.content)]),
  ])
}

/// Resolve a post's `image:` frontmatter value to a URL usable in an
/// `<img>` tag: absolute URLs pass through, relative paths resolve
/// against `/posts/<slug>/`. Shared with `render/page.gleam` so the
/// article hero and the OG meta never disagree. Labels disambiguate
/// the two `String` params.
pub fn resolve_image_url(slug slug: String, img img: String) -> String {
  case
    string.starts_with(img, "http://") || string.starts_with(img, "https://")
  {
    True -> img
    False -> {
      let expanded = case filepath.expand(img) {
        Ok(v) -> v
        Error(_) -> img
      }
      case filepath.is_absolute(expanded) {
        True -> expanded
        False -> filepath.join(filepath.join("/posts", slug), expanded)
      }
    }
  }
}
