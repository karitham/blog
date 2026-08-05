import data/model.{type Post, Post}
import gleam/string
import gleeunit/should
import lustre/element.{to_string}
import view/components/post_view

fn sample_post() -> Post {
  Post(
    title: "My Post",
    description: "A short summary",
    slug: "my-post",
    date: "2026-07-18",
    content: "<p>hello</p>",
    tags: ["gleam"],
    draft: False,
    image: "",
  )
}

pub fn render_single_includes_title_test() {
  let html = post_view.render_single(sample_post()) |> to_string
  string.contains(html, "My Post") |> should.be_true()
  string.contains(html, "Written") |> should.be_true()
}

pub fn render_list_empty_test() {
  let html = post_view.render_list([]) |> to_string
  string.contains(html, "No articles yet.") |> should.be_true()
}

pub fn render_list_renders_cards_test() {
  let html = post_view.render_list([sample_post()]) |> to_string
  string.contains(html, "My Post") |> should.be_true()
  string.contains(html, "/posts/my-post/") |> should.be_true()
}

pub fn render_single_hero_image_uses_resolved_url_test() {
  let post = Post(..sample_post(), image: "hero.png")
  let html = post_view.render_single(post) |> to_string
  string.contains(html, "/posts/my-post/hero.png") |> should.be_true()
}

pub fn resolve_image_url_passes_absolute_urls_test() {
  post_view.resolve_image_url("my-post", "https://example.com/x.png")
  |> should.equal("https://example.com/x.png")
}

pub fn resolve_image_url_resolves_relative_to_post_dir_test() {
  post_view.resolve_image_url("my-post", "hero.png")
  |> should.equal("/posts/my-post/hero.png")
}

pub fn resolve_image_url_resolves_dot_relative_test() {
  post_view.resolve_image_url("my-post", "./diagram.png")
  |> should.equal("/posts/my-post/diagram.png")
}
