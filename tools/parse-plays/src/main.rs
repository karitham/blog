//! CLI entry point and pipeline orchestration.
//!
//! Usage:
//!   parse-plays car <car-file|->                       dump raw plays as JSON
//!   parse-plays stats <plays.json|-> <stats-out> [--covers <cache.json>] [--images <dir>]
//!   parse-plays refresh <car-file|-> <stats-out> [--covers <cache.json>] [--images <dir>]
//!
//! refresh is the one-shot used by just refresh/CI: CAR in, stats out,
//! without materializing the raw JSON. Passing - streams stdin, so the
//! justfile can pipe curl straight into the process.

mod cache;
mod car;
mod images;
mod model;
mod net;
mod resolve;
mod sources;
mod stats;

#[cfg(test)]
mod testutil;

use crate::model::{Href, Play};
use std::collections::BTreeMap;
use std::str::FromStr;
use std::time::SystemTime;

#[tokio::main]
async fn main() {
    let args: Vec<String> = std::env::args().collect();
    let result = match args.get(1).map(String::as_str) {
        Some("car") => cmd_car(&args[2..]).await,
        Some("stats") => cmd_stats(&args[2..]),
        Some("refresh") => cmd_refresh(&args[2..]).await,
        _ => {
            eprintln!("usage:");
            eprintln!("  parse-plays car <car-file|->  — dump raw plays JSON to stdout");
            eprintln!(
                "  parse-plays stats <plays.json|-> <stats-out> [--covers <cache.json>] [--images <dir>]"
            );
            eprintln!(
                "  parse-plays refresh <car-file|-> <stats-out> [--covers <cache.json>] [--images <dir>]"
            );
            std::process::exit(2);
        }
    };
    if let Err(e) = result {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
}

#[derive(Default)]
struct Options {
    covers: Option<String>,
    images: Option<String>,
    profile: Option<String>,
}

/// Parse the --covers <path> / --images <dir> / --profile <handle>
/// options that trail the positional arguments. Unknown tokens are
/// ignored.
fn parse_options(args: &[String]) -> Options {
    let mut options = Options::default();
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--covers" => {
                options.covers = args.get(i + 1).cloned();
                i += 2;
            }
            "--images" => {
                options.images = args.get(i + 1).cloned();
                i += 2;
            }
            "--profile" => {
                options.profile = args.get(i + 1).cloned();
                i += 2;
            }
            _ => i += 1,
        }
    }
    options
}

async fn cmd_car(args: &[String]) -> Result<(), String> {
    let car_path = args.first().ok_or("missing <car-file>")?;
    let plays = car::read_plays(car_path).await?;
    serde_json::to_writer(std::io::stdout(), &plays)
        .map_err(|e| format!("failed to write JSON: {e}"))
}

fn cmd_stats(args: &[String]) -> Result<(), String> {
    let plays_path = args.first().ok_or("missing <plays.json>")?;
    let stats_out = args.get(1).ok_or("missing <stats-out>")?;
    let options = parse_options(&args[2..]);

    let raw: Vec<serde_json::Value> = if plays_path == "-" {
        serde_json::from_reader(std::io::BufReader::new(std::io::stdin()))
            .map_err(|e| format!("failed to parse plays from stdin: {e}"))?
    } else {
        std::fs::File::open(plays_path)
            .map_err(|e| format!("failed to open {}: {e}", plays_path))
            .map(std::io::BufReader::new)
            .and_then(|reader| {
                serde_json::from_reader(reader)
                    .map_err(|e| format!("failed to parse {}: {e}", plays_path))
            })?
    };
    let plays = parse_plays(&raw);
    write_stats(
        &plays,
        options.covers.as_deref(),
        stats_out,
        options.images.as_deref(),
        options.profile.as_deref(),
    )
}

async fn cmd_refresh(args: &[String]) -> Result<(), String> {
    let car_path = args.first().ok_or("missing <car-file>")?;
    let stats_out = args.get(1).ok_or("missing <stats-out>")?;
    let options = parse_options(&args[2..]);

    let raw = car::read_plays(car_path).await?;
    let plays = parse_plays(&raw);
    write_stats(
        &plays,
        options.covers.as_deref(),
        stats_out,
        options.images.as_deref(),
        options.profile.as_deref(),
    )
}

fn parse_plays(raw: &[serde_json::Value]) -> Vec<Play> {
    raw.iter().filter_map(Play::from_record).collect()
}

/// The impure-pure-impure sandwich: load the cache and needs, plan the
/// resolution (pure), fetch (impure), finalize (pure), then commit —
/// staged cache writes, the typed stats document, image mirroring, and
/// the stats file.
fn write_stats(
    plays: &[Play],
    cache_path: Option<&str>,
    stats_out: &str,
    images_dir: Option<&str>,
    profile: Option<&str>,
) -> Result<(), String> {
    let today = chrono::Utc::now().date_naive();
    let agg = stats::aggregate(plays, today);
    let needs = stats::needed(&agg);
    eprintln!(
        "resolving {} albums, {} artists, {} tracks",
        needs.albums.len(),
        needs.artists.len(),
        needs.tracks.len()
    );

    let mut cache = cache::Cache::load(cache_path);
    let now = SystemTime::now();
    let plan = resolve::plan(&needs, &cache, now);

    let sources = sources::MusicSources::new();
    let results = sources.run_queries(&plan);
    let mut fin = resolve::finalize(results, now);

    // One fallback round: provided release MBIDs with no Cover Art
    // Archive art get a name search (usually lands on the canonical
    // release).
    if !fin.pending.is_empty() {
        let fallback = resolve::ResolvePlan {
            resolved: Vec::new(),
            queries: std::mem::take(&mut fin.pending),
        };
        let results = sources.run_queries(&fallback);
        let fin2 = resolve::finalize(results, now);
        fin.resolutions.extend(fin2.resolutions);
        fin.writes.extend(fin2.writes);
    }

    let resolved = resolve::collect(&plan, &fin);
    cache.merge(fin.writes);
    if let Some(path) = cache_path {
        cache
            .save_atomically(path)
            .map_err(|e| format!("failed to save cache: {e}"))?;
    }

    let mut doc = stats::build_document(&agg, &resolved);
    if let Some(dir) = images_dir {
        let urls: Vec<Href> = resolved
            .cover
            .values()
            .chain(resolved.artist_cover.values())
            .cloned()
            .collect();
        let image_dir = std::path::Path::new(dir);
        let manifest = image_dir.with_file_name("img-cache.json");
        let mut store = images::ImageStore::load(image_dir, &manifest, "/img");
        let rewrites = store
            .mirror(sources.client.as_ref(), &sources.limits, &urls)
            .map_err(|e| format!("failed to mirror images: {e}"))?;
        images::rewrite_document(&mut doc, &rewrites);
        let keep = images::document_files(&doc);
        store
            .gc_files(&keep)
            .map_err(|e| format!("failed to collect image cache: {e}"))?;
        eprintln!("mirrored images into {dir}");
    }

    if let (Some(dir), Some(profile)) = (images_dir, profile)
        && let Err(e) = mirror_profile(&sources, std::path::Path::new(dir), profile)
    {
        eprintln!("warning: {e}");
    }

    std::fs::write(
        stats_out,
        serde_json::to_string_pretty(&doc).expect("serialize"),
    )
    .map_err(|e| format!("failed to write {stats_out}: {e}"))?;
    eprintln!("wrote {stats_out}");
    Ok(())
}

const BLUESKY_PUBLIC_API: &str = "https://public.api.bsky.app";

/// Mirror the profile avatar/banner through the same image store as
/// the music artwork and write the remote-to-local map the SSG reads.
/// A failed profile fetch leaves the previous map in place; the build
/// keeps using the last good local images.
fn mirror_profile(
    sources: &sources::MusicSources,
    images_dir: &std::path::Path,
    handle: &str,
) -> Result<(), String> {
    let Some(body) = sources.client.get_json(
        &format!("{BLUESKY_PUBLIC_API}/xrpc/app.bsky.actor.getProfile"),
        &[("actor", handle)],
    ) else {
        return Err(format!("failed to fetch profile {handle}"));
    };

    let urls: Vec<Href> = ["avatar", "banner"]
        .iter()
        .filter_map(|field| body.get(*field).and_then(|value| value.as_str()))
        .filter_map(|url| Href::from_str(url).ok())
        .collect();

    let profile_dir = images_dir.join("profile");
    let manifest = images_dir.with_file_name("profile-images-cache.json");
    let mut store = images::ImageStore::load(&profile_dir, &manifest, "/img/profile");
    let rewrites = store
        .mirror(sources.client.as_ref(), &sources.limits, &urls)
        .map_err(|e| format!("failed to mirror profile images: {e}"))?;
    let keep: std::collections::HashSet<String> = rewrites
        .values()
        .filter_map(|local| local.rsplit('/').next().map(str::to_string))
        .collect();
    store
        .gc_files(&keep)
        .map_err(|e| format!("failed to collect profile image cache: {e}"))?;

    let mapping: BTreeMap<String, String> = rewrites
        .into_iter()
        .map(|(url, local)| (url.as_ref().to_string(), local))
        .collect();
    let out = images_dir.with_file_name("profile-images.json");
    write_json_atomically(&out, &mapping)?;
    eprintln!("mirrored profile images into {}", profile_dir.display());
    Ok(())
}

fn write_json_atomically<T: serde::Serialize>(
    path: &std::path::Path,
    value: &T,
) -> Result<(), String> {
    let serialized = serde_json::to_string_pretty(value)
        .map_err(|e| format!("failed to serialize {}: {e}", path.display()))?;
    let tmp = path.with_extension("json.tmp");
    std::fs::write(&tmp, serialized)
        .map_err(|e| format!("failed to write {}: {e}", tmp.display()))?;
    std::fs::rename(&tmp, path).map_err(|e| format!("failed to rename {}: {e}", tmp.display()))
}
