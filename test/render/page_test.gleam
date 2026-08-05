import data/model.{type Post, type SiteData, Post, SiteData}
import gen/actor/defs.{type ProfileViewDetailed, ProfileViewDetailed}
import gleam/option.{None}
import gleam/string
import gleeunit/should
import lustre/element.{to_string}
import render/page
import stats

fn sample_profile() -> ProfileViewDetailed {
  ProfileViewDetailed(
    did: "did:plc:test",
    handle: "test.bsky.social",
    display_name: None,
    description: None,
    avatar: None,
    banner: None,
    followers_count: None,
    follows_count: None,
    posts_count: None,
    pronouns: None,
  )
}

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

fn sample_data() -> SiteData {
  SiteData(
    profile: sample_profile(),
    recent_plays: [],
    plays_stats: stats.empty_stats(),
    repos: [],
    posts: [sample_post()],
  )
}

pub fn index_page_renders_articles_and_post_test() {
  let html =
    page.index_page(sample_data(), "https://karitham.dev", [])
    |> to_string
  string.contains(html, "Articles") |> should.be_true()
  string.contains(html, "My Post") |> should.be_true()
  string.contains(html, "og:site_name") |> should.be_true()
}

pub fn index_page_embeds_rewrites_script_test() {
  let html =
    page.index_page(sample_data(), "https://karitham.dev", [
      #("https://remote/avatar.jpg", "/img/profile/avatar.jpg"),
    ])
    |> to_string
  string.contains(html, "image-rewrites") |> should.be_true()
  string.contains(html, "https://remote/avatar.jpg") |> should.be_true()
}

pub fn post_page_uses_site_url_for_og_url_test() {
  let html =
    page.post_page(sample_post(), sample_profile(), "https://example.com")
    |> to_string
  string.contains(html, "https://example.com/posts/my-post/")
  |> should.be_true()
}

pub fn post_page_absolutizes_post_image_for_og_test() {
  let post = Post(..sample_post(), image: "hero.png")
  let html =
    page.post_page(post, sample_profile(), "https://karitham.dev")
    |> to_string
  string.contains(html, "https://karitham.dev/posts/my-post/hero.png")
  |> should.be_true()
}

pub fn post_page_no_image_falls_back_to_avatar_none_test() {
  // No avatar in the profile and no post image: og:image is absent.
  let html =
    page.post_page(sample_post(), sample_profile(), "https://karitham.dev")
    |> to_string
  string.contains(html, "property=\"og:image\"") |> should.be_false()
}
