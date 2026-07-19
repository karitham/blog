import gleam/string

/// Returns the site URL, preferring the BLOG_URL environment variable
/// if set. Falls back to the hardcoded default.
pub fn site_url() -> String {
  case os_getenv("BLOG_URL") {
    Ok(url) -> string.trim(url)
    Error(_) -> "https://karitham.dev"
  }
}

@external(erlang, "api_ffi", "getenv")
fn os_getenv(name: String) -> Result(String, Nil)

pub const pds_endpoint = "https://eurosky.social"

pub const public_api = "https://public.api.bsky.app"

pub const did = "did:plc:kcgwlowulc3rac43lregdawo"

/// Shared by SSG and client so both render the same list length.
pub const plays_limit = 10
