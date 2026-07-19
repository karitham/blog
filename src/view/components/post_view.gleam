import card
import data/model.{type Post}
import date
import gleam/list
import gleam/option.{None}
import lustre/attribute.{class}
import lustre/element.{type Element, none, text, unsafe_raw_html}
import lustre/element/html.{div, h1, p, span}

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
  let tags = case post.tags {
    [] -> none()
    ts ->
      div(
        [class("tags")],
        list.map(ts, fn(t) { span([class("emph")], [text(t)]) }),
      )
  }

  div([class("post")], [
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
