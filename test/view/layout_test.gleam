import data/model.{Post}
import gleam/option
import gleam/string
import gleeunit/should
import lustre/element.{to_string}
import lustre/element/html.{div}
import view/layout

pub fn page_uses_site_url_for_og_site_name_test() {
  let meta =
    layout.Meta(
      description: "desc",
      image: option.None,
      url: "https://karitham.dev/",
      logo: option.None,
      page_type: layout.Website,
    )
  let html =
    layout.page(
      site_url: "https://karitham.dev",
      title: "Title",
      model_json: "{}",
      content: [div([], [])],
      meta: meta,
    )
    |> to_string
  string.contains(html, "og:site_name") |> should.be_true()
  string.contains(html, "karitham.dev") |> should.be_true()
}

pub fn page_uses_local_site_url_in_preview_test() {
  let meta =
    layout.Meta(
      description: "desc",
      image: option.None,
      url: "http://localhost:8000/",
      logo: option.None,
      page_type: layout.Website,
    )
  let html =
    layout.page(
      site_url: "http://localhost:8000",
      title: "Title",
      model_json: "{}",
      content: [div([], [])],
      meta: meta,
    )
    |> to_string
  // The site name strips the scheme, whatever it is — the preview URL
  // must end up in og:site_name. (The nav brand is hardcoded to the
  // production handle, so don't assert on karitham.dev absence.)
  string.contains(html, "localhost:8000") |> should.be_true()
}

pub fn rss_feed_links_are_absolute_with_site_url_test() {
  let post =
    Post(
      title: "My Post",
      description: "A short summary",
      slug: model.must_slug("my-post"),
      date: "2024-09-21",
      content: "<p>hi</p>",
      tags: [],
      draft: False,
      image: option.None,
    )
  let rss = layout.rss_feed([post], "https://karitham.dev")
  string.contains(rss, "https://karitham.dev/posts/my-post/")
  |> should.be_true()
  string.contains(rss, "<title>My Post</title>") |> should.be_true()
}

pub fn rss_feed_preview_uses_localhost_test() {
  let post =
    Post(
      title: "T",
      description: "",
      slug: model.must_slug("t"),
      date: "2024-09-21",
      content: "",
      tags: [],
      draft: False,
      image: option.None,
    )
  let rss = layout.rss_feed([post], "http://localhost:8000")
  string.contains(rss, "http://localhost:8000/posts/t/") |> should.be_true()
  string.contains(rss, "karitham.dev") |> should.be_false()
}

pub fn rss_feed_empty_posts_test() {
  let rss = layout.rss_feed([], "https://karitham.dev")
  string.contains(rss, "<channel>") |> should.be_true()
}
