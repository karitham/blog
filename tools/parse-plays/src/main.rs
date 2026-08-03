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
mod stats;

use serde_json::json;

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
            eprintln!("  parse-plays stats <plays.json|-> <stats-out> [--covers <cache.json>]");
            eprintln!("  parse-plays refresh <car-file> <stats-out> [--covers <cache.json>]");
            std::process::exit(2);
        }
    };
    if let Err(e) = result {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
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
    let cache_path = match args.get(2).map(String::as_str) {
        Some("--covers") => args.get(3).map(String::as_str),
        _ => None,
    };

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
    write_stats(&agg, cache_path, stats_out)
}

async fn cmd_refresh(args: &[String]) -> Result<(), String> {
    let car_path = args.first().ok_or("missing <car-file>")?;
    let stats_out = args.get(1).ok_or("missing <stats-out>")?;
    let cache_path = match args.get(2).map(String::as_str) {
        Some("--covers") => args.get(3).map(String::as_str),
        _ => None,
    };

    // Gather: raw history straight from the CAR, no JSON round-trip.
    let plays = car::read_plays(car_path).await?;

    // Process (pure).
    let agg = stats::aggregate(&plays, chrono::Utc::now().date_naive());

    // Commit (impure).
    write_stats(&agg, cache_path, stats_out)
}

/// Shared tail of `stats` and `refresh`: resolve covers and artist
/// images for the top-N entries, serialize the grids, write the stats
/// file.
fn write_stats(
    agg: &stats::Aggregated,
    cache_path: Option<&str>,
    stats_out: &str,
) -> Result<(), String> {
    let pairs = stats::needed_pairs(agg);
    let artists = stats::needed_artists(agg);

    eprintln!(
        "resolving {} album covers, {} artist images",
        pairs.len(),
        artists.len()
    );
    let cover_map = covers::resolve(&pairs, cache_path);
    let artist_map = covers::resolve_artists(&artists, cache_path);
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

    let stats_json = stats::build_ranges(agg, &cover, &artist_cover);
    let doc = json!({ "ranges": stats_json });
    std::fs::write(
        stats_out,
        serde_json::to_string_pretty(&doc).expect("serialize"),
    )
    .map_err(|e| format!("failed to write {stats_out}: {e}"))?;
    eprintln!("wrote {stats_out}");
    Ok(())
}
