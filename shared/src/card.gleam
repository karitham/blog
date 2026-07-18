//// Shared card UI primitive.
////
//// Used by both the article list (post titles linking internally) and
//// the repos list (project names linking to Tangled, opening in a new
//// tab). Keeps the `.card*` CSS classes in one place so the two views
//// can't drift in markup.

import gleam/list
import gleam/option.{type Option, None, Some}
import lustre/attribute.{class, href, target}
import lustre/element.{type Element, none, text}
import lustre/element/html.{a, div, span}

/// Build a card with a titled link, a date, an optional description,
/// and optional topic tags. `title_target` lets the caller choose
/// whether the link opens in a new tab (`Some("_blank")`) or in the
/// current tab (`None`).
pub fn card(
  title_href url: String,
  title_text title: String,
  title_target title_target: Option(String),
  date date: String,
  description description: String,
  topics topics: List(String),
) -> Element(msg) {
  let title_attrs = case title_target {
    Some(t) -> [href(url), target(t), class("card-title")]
    None -> [href(url), class("card-title")]
  }
  let desc = case description {
    "" -> none()
    d -> div([class("card-desc")], [text(d)])
  }
  let topic_tags = case topics {
    [] -> none()
    ts ->
      div(
        [class("card-tags")],
        list.map(ts, fn(t: String) { span([class("card-tag")], [text(t)]) }),
      )
  }
  div([class("card")], [
    div([class("card-head")], [
      a(title_attrs, [text(title)]),
      span([class("card-date")], [text(date)]),
    ]),
    desc,
    topic_tags,
  ])
}
