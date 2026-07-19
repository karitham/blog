import card
import data/model.{type Post}
import date
import filepath
import gleam/list
import gleam/option.{None}
import gleam/result
import gleam/string
import lustre/attribute.{alt, class, src}
import lustre/element.{type Element, none, text, unsafe_raw_html}
import lustre/element/html.{div, h1, img, p, span}

pub fn render_list(posts: List(Post)) -> Element(Nil) {
  case posts {
    [] -> p([], [text("No articles yet.")])
    _ -> div([], list.map(posts, render_article_card))
  }
}

fn render_article_card(post: Post) -> Element(Nil) {
  card.card(
    title_href: "/posts/" <> post.slug <> "/",
    title_text: post.title,
    title_target: None,
    date: date.format_ymd(post.date),
    description: post.description,
    topics: post.tags,
  )
}

pub fn render_single(post: Post) -> Element(Nil) {
  let hero_image = case post.image {
    "" -> none()
    image_path -> {
      let image_src = resolve_image_url(post.slug, image_path)
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

fn resolve_image_url(slug: String, img: String) -> String {
  case
    string.starts_with(img, "http://") || string.starts_with(img, "https://")
  {
    True -> img
    False -> {
      let expanded = filepath.expand(img) |> result.unwrap(img)
      case filepath.is_absolute(expanded) {
        True -> expanded
        False -> filepath.join(filepath.join("/posts", slug), expanded)
      }
    }
  }
}
