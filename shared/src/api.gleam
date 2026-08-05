/// Shared constants for AT Protocol endpoints and site identity.
///
/// Pure constants only — no FFI, no environment reads, so this module
/// compiles and behaves identically on Erlang and JS. The site URL
/// used for OG/RSS absolute links lives in the SSG's `config.gleam`
/// (`BLOG_URL`), not here.
pub const pds_endpoint = "https://eurosky.social"

pub const public_api = "https://public.api.bsky.app"

pub const did = "did:plc:kcgwlowulc3rac43lregdawo"

/// Shared by SSG and client so both render the same list length.
pub const plays_limit = 10
