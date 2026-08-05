//! CLI entry point and pipeline orchestration.
//!
//! Usage:
//!   parse-plays car <car-file>                        dump every play as JSON to stdout
//!   parse-plays stats <plays.json|-> <stats-out> [--covers <cover-cache.json>]
//!   parse-plays refresh <car-file> <stats-out> [--covers <cover-cache.json>]
//!
//! `car` reads a repository CAR file and dumps the raw play history
//! (a JSON array of record objects) to stdout.
//!
//! `stats` reads that JSON dump (or stdin when the path is `-`),
//! aggregates top-N artists/albums/tracks per time range (pure, in
//! `stats`), hydrates covers/links through the impure `sources`
//! boundary, and writes the small stats file the SSG reads at build.
//!
//! `refresh` is the one-shot used by `just refresh`/CI: CAR in, stats
//! out, without ever materializing the ~100MB JSON dump.
//!
//! The pipeline is a strict impure-pure-impure sandwich: gather the
//! cache + needs, decide what to fetch purely (`resolve::plan`), fetch
//! (`sources`), fold the outcomes purely (`resolve::finalize`), then
//! commit (cache save, image mirroring, stats write).

mod cache;
mod car;
mod images;
mod model;
mod net;
mod resolve;
mod sources;
mod stats;

use serde_json::json;
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
            eprintln!("  parse-plays car <car-file>  — dump plays JSON to stdout");
            eprintln!(
                "  parse-plays stats <plays.json|-> <stats-out> [--covers <cache.json>] [--images <dir>]"
            );
            eprintln!(
                "  parse-plays refresh <car-file> <stats-out> [--covers <cache.json>] [--images <dir>]"
            );
            std::process::exit(2);
        }
    };
    if let Err(e) = result {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
}

/// Parse the `--covers <path>` / `--images <dir>` options that trail
/// the positional arguments. Unknown tokens are ignored.
fn parse_options(args: &[String]) -> (Option<String>, Option<String>) {
    let mut covers = None;
    let mut images = None;
    let mut i = 0;
    while i < args.len() {
        match args[i].as_str() {
            "--covers" => {
                covers = args.get(i + 1).cloned();
                i += 2;
            }
            "--images" => {
                images = args.get(i + 1).cloned();
                i += 2;
            }
            _ => i += 1,
        }
    }
    (covers, images)
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
    let (cache_path, images_dir) = parse_options(&args[2..]);

    // Gather: raw history from the previous pipeline step. `-` reads
    // stdin so `parse-plays car ... | parse-plays stats - ...` avoids
    // materializing the ~100MB dump on disk.
    let plays: Vec<serde_json::Value> = if plays_path == "-" {
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

    // Process (pure): aggregate and figure out which covers we need.
    let agg = stats::aggregate(&plays, chrono::Utc::now().date_naive());

    // Commit (impure): resolve through the cache, then serialize.
    write_stats(
        &agg,
        cache_path.as_deref(),
        stats_out,
        images_dir.as_deref(),
    )
}

async fn cmd_refresh(args: &[String]) -> Result<(), String> {
    let car_path = args.first().ok_or("missing <car-file>")?;
    let stats_out = args.get(1).ok_or("missing <stats-out>")?;
    let (cache_path, images_dir) = parse_options(&args[2..]);

    // Gather: raw history straight from the CAR, no JSON round-trip.
    let plays = car::read_plays(car_path).await?;

    // Process (pure).
    let agg = stats::aggregate(&plays, chrono::Utc::now().date_naive());

    // Commit (impure).
    write_stats(
        &agg,
        cache_path.as_deref(),
        stats_out,
        images_dir.as_deref(),
    )
}

/// The impure-pure-impure sandwich: load the cache and the needs,
/// plan the resolution (pure), fetch (impure), finalize (pure), then
/// commit — staged cache writes, image mirroring, and the stats file.
fn write_stats(
    agg: &stats::Aggregated,
    cache_path: Option<&str>,
    stats_out: &str,
    images_dir: Option<&str>,
) -> Result<(), String> {
    // Gather: needs + cache.
    let needs = stats::needed(agg);
    eprintln!(
        "resolving {} album covers, {} artist images, {} links",
        needs.albums.len(),
        needs.artists.len(),
        needs.albums.len() + needs.artists.len() + needs.tracks.len()
    );
    let mut cache = cache::Cache::load(cache_path);
    let now = SystemTime::now();

    // Process: decide what the cache can't satisfy.
    let plan = resolve::plan(&needs, &cache, now);

    // Gather: fetch the queries (MusicBrainz/CAA/Wikidata).
    let sources = sources::MusicSources::new();
    let results = sources.run_queries(&plan);

    // Process: fold outcomes into resolutions + staged cache writes.
    let mut fin = resolve::finalize(&plan, results, now);

    // One fallback round: provided MBIDs with no Cover Art Archive art
    // get a name search (usually lands on the canonical release).
    if !fin.pending.is_empty() {
        let fallback = resolve::ResolvePlan {
            resolved: Vec::new(),
            queries: std::mem::take(&mut fin.pending),
        };
        let results = sources.run_queries(&fallback);
        let fin2 = resolve::finalize(&fallback, results, now);
        fin.resolutions.extend(fin2.resolutions);
        fin.writes.extend(fin2.writes);
    }

    // Commit: staged cache writes once, then the stats document.
    let resolved = resolve::collect(&plan, &fin);
    cache.merge(fin.writes);
    if let Some(path) = cache_path {
        cache
            .save_atomically(path)
            .map_err(|e| format!("failed to save cache: {e}"))?;
    }

    let mut doc = json!({ "ranges": stats::build_ranges(agg, &resolved) });
    if let Some(dir) = images_dir {
        // Mirror the remote images beside the site so the browser
        // never hits Cover Art Archive / Wikimedia at page load.
        let image_urls: Vec<model::Href> = resolved
            .cover
            .values()
            .chain(resolved.artist_cover.values())
            .cloned()
            .collect();
        let download_map = images::download_many(
            &sources.client,
            &sources.limits,
            &image_urls,
            std::path::Path::new(dir),
        );
        eprintln!("mirrored images into {dir}");
        // Point the image fields at the local mirrors; any URL missing
        // from the map (failed download) keeps its remote value.
        images::apply_rewrites(&mut doc, &download_map);
    }

    std::fs::write(
        stats_out,
        serde_json::to_string_pretty(&doc).expect("serialize"),
    )
    .map_err(|e| format!("failed to write {stats_out}: {e}"))?;
    eprintln!("wrote {stats_out}");
    Ok(())
}
