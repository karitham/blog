import data/model.{type Post}
import date
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import lustre/attribute
import lustre/element.{type Element, none, text}
import lustre/element/html
import lustre/element/svg

/// Controls the og:type and article-specific meta tags.
pub type PageType {
  Website
  Article(published_time: String, tags: List(String))
}

/// Metadata used to populate OG/Twitter card meta tags.
pub type Meta {
  Meta(
    description: String,
    image: Option(String),
    url: String,
    logo: Option(String),
    page_type: PageType,
  )
}

/// Render the full document shell. `site_url` is threaded in (not
/// read from the environment) so the whole view layer is pure and
/// testable with a fixed URL.
pub fn page(
  site_url: String,
  title: String,
  content: Element(Nil),
  meta: Meta,
) -> Element(Nil) {
  html.html([attribute.lang("en")], [
    html.head([], head_children(site_url, title, meta)),
    html.body([], [
      html.div([attribute.id("content")], [
        nav_bar(),
        html.div([attribute.id("main")], [content]),
        footer_bar(),
      ]),
    ]),
  ])
}

fn head_children(
  site_url: String,
  title: String,
  meta: Meta,
) -> List(Element(Nil)) {
  let base = [
    html.meta([attribute.charset("UTF-8")]),
    html.meta([
      attribute.attribute("name", "viewport"),
      attribute.content("width=device-width, initial-scale=1"),
    ]),
    // Description
    html.meta([
      attribute.attribute("name", "description"),
      attribute.content(meta.description),
    ]),
    // Primary
    html.title([], title),
    // Open Graph
    html.meta([
      attribute.attribute("property", "og:site_name"),
      attribute.content(string.replace(site_url, "https://", "")),
    ]),
    html.meta([
      attribute.attribute("property", "og:type"),
      attribute.content(og_type_name(meta.page_type)),
    ]),
    html.meta([
      attribute.attribute("property", "og:url"),
      attribute.content(meta.url),
    ]),
    html.meta([
      attribute.attribute("property", "og:title"),
      attribute.content(title),
    ]),
    html.meta([
      attribute.attribute("property", "og:description"),
      attribute.content(meta.description),
    ]),
    case meta.image {
      Some(img) ->
        html.meta([
          attribute.attribute("property", "og:image"),
          attribute.content(img),
        ])
      None -> none()
    },
    // Twitter card
    html.meta([
      attribute.attribute("name", "twitter:card"),
      attribute.content("summary_large_image"),
    ]),
    html.meta([
      attribute.attribute("name", "twitter:site"),
      attribute.content("@KarithamIRL"),
    ]),
    html.meta([
      attribute.attribute("name", "twitter:author"),
      attribute.content("@KarithamIRL"),
    ]),
    html.meta([
      attribute.attribute("name", "twitter:title"),
      attribute.content(title),
    ]),
    html.meta([
      attribute.attribute("name", "twitter:description"),
      attribute.content(meta.description),
    ]),
    case meta.image {
      Some(img) ->
        html.meta([
          attribute.attribute("name", "twitter:image"),
          attribute.content(img),
        ])
      None -> none()
    },
    // Brand logo (used by some platforms in addition to og:image)
    case meta.logo {
      Some(logo) ->
        html.meta([
          attribute.attribute("property", "og:logo"),
          attribute.content(logo),
        ])
      None -> none()
    },
    // Styles, icons, scripts
    html.link([attribute.rel("stylesheet"), attribute.href("/style.css")]),
    html.link([
      attribute.rel("icon"),
      attribute.type_("image/png"),
      attribute.attribute("sizes", "32x32"),
      attribute.href("/favicon-32x32.png"),
    ]),
    html.link([
      attribute.rel("icon"),
      attribute.type_("image/png"),
      attribute.attribute("sizes", "16x16"),
      attribute.href("/favicon-16x16.png"),
    ]),
    html.link([
      attribute.rel("apple-touch-icon"),
      attribute.attribute("sizes", "180x180"),
      attribute.href("/apple-touch-icon.png"),
    ]),
    html.link([
      attribute.rel("manifest"),
      attribute.href("/site.webmanifest"),
    ]),
    // Vendored highlight.js (common bundle) — must load before the module below.
    // `defer` keeps the download off the critical path while ensuring the
    // script executes before any DOMContentLoaded listeners (including the
    // module below, which runs after DOMContentLoaded).
    html.script(
      [attribute.attribute("defer", ""), attribute.src("/highlight.min.js")],
      "",
    ),
    // Init module: registers gleam + nushell grammars and calls highlightAll().
    html.script(
      [attribute.type_("module"), attribute.src("/highlight.mjs")],
      "",
    ),
    html.script(
      [attribute.type_("module")],
      "import{main}from'/client/karitham_blog_client/client.mjs';main();",
    ),
  ]

  list.append(base, article_meta_tags(meta.page_type))
}

fn og_type_name(page_type: PageType) -> String {
  case page_type {
    Website -> "website"
    Article(_, _) -> "article"
  }
}

fn article_meta_tags(page_type: PageType) -> List(Element(Nil)) {
  case page_type {
    Website -> []
    Article(published_time:, tags:) ->
      list.append(
        [
          html.meta([
            attribute.attribute("property", "article:published_time"),
            attribute.content(published_time),
          ]),
        ],
        list.map(tags, fn(tag) {
          html.meta([
            attribute.attribute("property", "article:tag"),
            attribute.content(tag),
          ])
        }),
      )
  }
}

fn nav_bar() -> Element(Nil) {
  html.nav([attribute.id("nav")], [
    html.a([attribute.href("/")], [text("~/karitham.dev")]),
  ])
}

fn footer_bar() -> Element(Nil) {
  html.footer([], [
    html.div([attribute.id("socials"), attribute.class("row")], [
      icon_github(),
      icon_linkedin(),
      icon_discord(),
      icon_bluesky(),
      icon_email(),
    ]),
    html.p([], [
      text("built with "),
      html.a([attribute.href("https://gleam.run")], [text("Gleam")]),
      text(" · styled with "),
      html.a([attribute.href("https://catppuccin.com")], [text("Catppuccin")]),
    ]),
  ])
}

fn icon_github() -> Element(Nil) {
  html.a(
    [attribute.href("https://github.com/Karitham"), attribute.target("_blank")],
    [
      svg.svg(
        [
          attribute.width(32),
          attribute.height(32),
          attribute.attribute("viewBox", "0 0 24 24"),
        ],
        [
          svg.path([
            attribute.attribute(
              "d",
              "M6.517 17.113c.395.578 1.592 1.81 3.225 2.12M9.864 22C8.836 21.83 2 19.606 2 12.093C2 5.063 8.002 2 12 2c4 0 10 3.063 10 10.093c0 7.513-6.836 9.738-7.864 9.907c0 0-.21-3.417-.087-4.003c.122-.586-.294-1.528-.294-1.528c.971-.364 2.45-.884 2.945-2.282c.385-1.084.627-2.658-.45-4.138c0 0 .282-2.39-.25-2.484c-.533-.092-2.1.947-2.1.947c-.457-.13-1.476-.377-1.898-.333c-.423-.044-1.445.203-1.902.333c0 0-1.568-1.04-2.1-.947s-.25 2.484-.25 2.484c-1.077 1.48-.835 3.054-.45 4.138c.496 1.398 1.974 1.918 2.945 2.282c0 0-.416.942-.294 1.528S9.864 22 9.864 22",
            ),
          ]),
        ],
      ),
    ],
  )
}

fn icon_linkedin() -> Element(Nil) {
  html.a(
    [
      attribute.href("https://linkedin.com/in/pl-pery"),
      attribute.target("_blank"),
    ],
    [
      svg.svg(
        [
          attribute.width(32),
          attribute.height(32),
          attribute.attribute("viewBox", "0 0 24 24"),
        ],
        [
          svg.path([
            attribute.attribute(
              "d",
              "M4.5 9.5H4c-.943 0-1.414 0-1.707.293S2 10.557 2 11.5V20c0 .943 0 1.414.293 1.707S3.057 22 4 22h.5c.943 0 1.414 0 1.707-.293S6.5 20.943 6.5 20v-8.5c0-.943 0-1.414-.293-1.707S5.443 9.5 4.5 9.5m2-5.25a2.25 2.25 0 1 1-4.5 0a2.25 2.25 0 0 1 4.5 0m5.826 5.25H11.5c-.943 0-1.414 0-1.707.293S9.5 10.557 9.5 11.5V20c0 .943 0 1.414.293 1.707S10.557 22 11.5 22h.5c.943 0 1.414 0 1.707-.293S14 20.943 14 20v-3.5c0-1.657.528-3 2.088-3c.78 0 1.412.672 1.412 1.5v4.5c0 .943 0 1.414.293 1.707s.764.293 1.707.293h.499c.942 0 1.414 0 1.707-.293c.292-.293.293-.764.293-1.706L22 14c0-2.486-2.364-4.5-4.703-4.5c-1.332 0-2.52.652-3.297 1.673c0-.63 0-.945-.137-1.179a1 1 0 0 0-.358-.358c-.234-.137-.549-.137-1.179-.137",
            ),
          ]),
        ],
      ),
    ],
  )
}

fn icon_discord() -> Element(Nil) {
  html.a(
    [
      attribute.href("https://discord.com/users/206794847581896705"),
      attribute.target("_blank"),
    ],
    [
      svg.svg(
        [
          attribute.width(32),
          attribute.height(32),
          attribute.attribute("viewBox", "0 0 24 24"),
        ],
        [
          svg.path([
            attribute.attribute(
              "d",
              "M19.27 5.33C17.94 4.71 16.5 4.26 15 4a.1.1 0 0 0-.07.03c-.18.33-.39.76-.53 1.09a16.1 16.1 0 0 0-4.8 0c-.14-.34-.35-.76-.54-1.09c-.01-.02-.04-.03-.07-.03c-1.5.26-2.93.71-4.27 1.33c-.01 0-.02.01-.03.02c-2.72 4.07-3.47 8.03-3.1 11.95c0 .02.01.04.03.05c1.8 1.32 3.53 2.12 5.24 2.65c.03.01.06 0 .07-.02c.4-.55.76-1.13 1.07-1.74c.02-.04 0-.08-.04-.09c-.57-.22-1.11-.48-1.64-.78c-.04-.02-.04-.08-.01-.11c.11-.08.22-.17.33-.25c.02-.02.05-.02.07-.01c3.44 1.57 7.15 1.57 10.55 0c.02-.01.05-.01.07.01c.11.09.22.17.33.26c.04.03.04.09-.01.11c-.52.31-1.07.56-1.64.78c-.04.01-.05.06-.04.09c.32.61.68 1.19 1.07 1.74c.03.01.06.02.09.01c1.72-.53 3.45-1.33 5.25-2.65c.02-.01.03-.03.03-.05c.44-4.53-.73-8.46-3.1-11.95c-.01-.01-.02-.02-.04-.02M8.52 14.91c-1.03 0-1.89-.95-1.89-2.12s.84-2.12 1.89-2.12c1.06 0 1.9.96 1.89 2.12c0 1.17-.84 2.12-1.89 2.12m6.97 0c-1.03 0-1.89-.95-1.89-2.12s.84-2.12 1.89-2.12c1.06 0 1.9.96 1.89 2.12c0 1.17-.83 2.12-1.89 2.12",
            ),
          ]),
        ],
      ),
    ],
  )
}

fn icon_bluesky() -> Element(Nil) {
  html.a(
    [
      attribute.href("https://bsky.app/profile/karitham.dev"),
      attribute.target("_blank"),
    ],
    [
      svg.svg(
        [
          attribute.role("img"),
          attribute.attribute("viewBox", "0 0 24 24"),
        ],
        [
          svg.title([], [text("Bluesky")]),
          svg.path([
            attribute.attribute(
              "d",
              "M12 10.8c-1.087-2.114-4.046-6.053-6.798-7.995C2.566.944 1.561 1.266.902 1.565.139 1.908 0 3.08 0 3.768c0 .69.378 5.65.624 6.479.815 2.736 3.713 3.66 6.383 3.364.136-.02.275-.039.415-.056-.138.022-.276.04-.415.056-3.912.58-7.387 2.005-2.83 7.078 5.013 5.19 6.87-1.113 7.823-4.308.953 3.195 2.05 9.271 7.733 4.308 4.267-4.308 1.172-6.498-2.74-7.078a8.741 8.741 0 0 1-.415-.056c.14.017.279.036.415.056 2.67.297 5.568-.628 6.383-3.364.246-.828.624-5.79.624-6.478 0-.69-.139-1.861-.902-2.206-.659-.298-1.664-.62-4.3 1.24C16.046 4.748 13.087 8.687 12 10.8Z",
            ),
          ]),
        ],
      ),
    ],
  )
}

fn icon_email() -> Element(Nil) {
  html.a(
    [attribute.href("mailto:pl@karitham.dev"), attribute.target("_blank")],
    [
      svg.svg(
        [
          attribute.width(32),
          attribute.height(32),
          attribute.attribute("viewBox", "0 0 24 24"),
        ],
        [
          svg.path([
            attribute.attribute(
              "d",
              "M21.75 6.75v10.5a2.25 2.25 0 0 1-2.25 2.25h-15a2.25 2.25 0 0 1-2.25-2.25V6.75m19.5 0A2.25 2.25 0 0 0 19.5 4.5h-15a2.25 2.25 0 0 0-2.25 2.25m19.5 0v.243a2.25 2.25 0 0 1-1.07 1.916l-7.5 4.615a2.25 2.25 0 0 1-2.36 0L3.32 8.91a2.25 2.25 0 0 1-1.07-1.916V6.75",
            ),
          ]),
        ],
      ),
    ],
  )
}

/// Render the RSS feed. `site_url` is threaded in so absolute links
/// are correct in local previews (`BLOG_URL=http://localhost:8000`).
pub fn rss_feed(posts: List(Post), site_url: String) -> String {
  let items = list.map(posts, fn(post) { "  <item>
    <title>" <> post.title <> "</title>
    <description>" <> post.description <> "</description>
    <link>" <> site_url <> "/posts/" <> post.slug <> "/</link>
    <pubDate>" <> date.to_rfc822(post.date) <> "</pubDate>
  </item>" })

  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\">
  <channel>
    <title>Karitham's Thoughts</title>
    <link>" <> site_url <> "</link>
    <description>Kar's thoughts</description>
    <language>en</language>
    <atom:link href=\"" <> site_url <> "/rss.xml\" rel=\"self\" type=\"application/rss+xml\"/>
    " <> string.join(items, "\n") <> "
  </channel>
</rss>"
}
