//// Build-time site configuration. The only module that reads the
//// environment — everything downstream receives the values as plain
//// parameters, so render code stays pure and testable.

import gleam/string

pub type SiteConfig {
  SiteConfig(site_url: String, dist_dir: String)
}

/// Read `BLOG_URL` (falls back to the production URL) and the output
/// directory. Called once at the top of `build.build()`.
pub fn read_env() -> SiteConfig {
  SiteConfig(
    site_url: case os_getenv("BLOG_URL") {
      Ok(url) -> string.trim(url)
      Error(_) -> "https://karitham.dev"
    },
    dist_dir: "./dist",
  )
}

@external(erlang, "config_ffi", "getenv")
fn os_getenv(name: String) -> Result(String, Nil)
