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
//! `stats`), hydrates cover art through the cached MusicBrainz +
//! Cover Art Archive pipeline (impure, in `covers`), and writes the
//! small stats file the SSG reads at build.
//!
//! `refresh` is the one-shot used by `just refresh`/CI: CAR in, stats
//! out, without ever materializing the ~100MB JSON dump.

mod car;
mod covers;
mod images;
mod net;
mod stats;

use serde_json::json;
use std::collections::HashMap;

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

    // Commit (impure): resolve covers through the cache, then serialize.
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

/// Shared tail of `stats` and `refresh`: resolve covers, artist
/// images, and MusicBrainz page links for the top-N entries, mirror
/// the remote images into a local dir, serialize the grids, write the
/// stats file.
fn write_stats(
    agg: &stats::Aggregated,
    cache_path: Option<&str>,
    stats_out: &str,
    images_dir: Option<&str>,
) -> Result<(), String> {
    let pairs = stats::needed_pairs(agg);
    let artists = stats::needed_artists(agg);
    let tracks = stats::needed_tracks(agg);

    eprintln!(
        "resolving {} album covers, {} artist images, {} links",
        pairs.len(),
        artists.len(),
        pairs.len() + artists.len() + tracks.len()
    );

    // Shared lookup cache: loaded once, written by every phase under
    // the mutex, persisted once after all phases. Without a cache path
    // we still share an (empty) cache — behavior is unchanged.
    let cache = std::sync::Mutex::new(cache_path.map(covers::load_cache).unwrap_or_default());

    // Stage 1: the image sources — cover art and artist photos. These
    // two are the slow ones (MusicBrainz + Wikidata chains), so they
    // run first and in parallel.
    let (cover_map, artist_map) = rayon::join(
        || covers::resolve(&pairs, &cache),
        || covers::resolve_artists(&artists, &cache),
    );

    // Stage 2: mirror the images in parallel with resolving the
    // MusicBrainz page links — the downloads only need the two image
    // maps from stage 1, so the URL lookups overlap them instead of
    // running serially before them.
    let image_urls: Vec<String> = cover_map
        .values()
        .chain(artist_map.values())
        .cloned()
        .collect();
    let mut download_map: HashMap<String, String> = HashMap::new();
    let mut album_url_map = HashMap::new();
    let mut artist_url_map = HashMap::new();
    let mut track_url_map = HashMap::new();
    rayon::scope(|s| {
        if let Some(dir) = images_dir {
            s.spawn(|_| {
                download_map = images::download_many(&image_urls, std::path::Path::new(dir));
            });
        }
        s.spawn(|_| album_url_map = covers::resolve_album_urls(&pairs, &cache));
        s.spawn(|_| artist_url_map = covers::resolve_artist_urls(&artists, &cache));
        s.spawn(|_| track_url_map = covers::resolve_track_urls(&tracks, &cache));
    });
    if let Some(dir) = images_dir {
        eprintln!("mirrored images into {dir}");
    }

    // Persist the merged cache once, after every phase has finished.
    if let Some(path) = cache_path {
        covers::save_cache_atomically(path, &cache.into_inner().unwrap());
    }

    let cover = |artist: &str, album: &str| -> String {
        cover_map
            .get(&(stats::normalize(artist), stats::normalize(album)))
            .cloned()
            .unwrap_or_default()
    };
    let artist_cover = |name: &str| -> String {
        artist_map
            .get(&stats::normalize(name))
            .cloned()
            .unwrap_or_default()
    };
    let album_url = |artist: &str, album: &str| -> String {
        album_url_map
            .get(&(stats::normalize(artist), stats::normalize(album)))
            .cloned()
            .unwrap_or_default()
    };
    let artist_url = |name: &str| -> String {
        artist_url_map
            .get(&stats::normalize(name))
            .cloned()
            .unwrap_or_default()
    };
    let track_url = |artist: &str, track: &str| -> String {
        track_url_map
            .get(&(stats::normalize(artist), stats::normalize(track)))
            .cloned()
            .unwrap_or_default()
    };
    let lookups = stats::Lookups {
        cover: &cover,
        artist_cover: &artist_cover,
        album_url: &album_url,
        artist_url: &artist_url,
        track_url: &track_url,
    };

    let stats_json = stats::build_ranges(agg, &lookups);
    let mut doc = json!({ "ranges": stats_json });
    // Point the image fields at the local mirrors; any URL missing
    // from the map (failed download) keeps its remote value.
    images::apply_rewrites(&mut doc, &download_map);
    std::fs::write(
        stats_out,
        serde_json::to_string_pretty(&doc).expect("serialize"),
    )
    .map_err(|e| format!("failed to write {stats_out}: {e}"))?;
    eprintln!("wrote {stats_out}");
    Ok(())
}
