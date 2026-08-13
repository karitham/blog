//! CAR file → play records (repo-stream I/O).

use repo_stream::{DiskBuilder, Driver, DriverBuilder};
use serde_json::Value;

/// Teal dropped the `alpha` namespace, but historical plays live in
/// the old collection. Stats aggregate both — all-time grids must
/// count the alpha era — while the site's live rows only read the
/// current collection.
const PLAY_COLLECTIONS: [&str; 2] = ["fm.teal.feed.play", "fm.teal.alpha.feed.play"];

/// Cap on the buffered (play-filtered) blocks before repo-stream
/// spills to disk. The current repo needs ~75 MiB; 256 MiB leaves
/// room to grow while staying in the in-memory fast path.
const MEM_LIMIT_MB: usize = 256;

/// Whether a decoded record block is a play record. Extracted from the
/// block processor so the filter is testable without a CAR fixture.
pub(crate) fn is_play_record(record: &Value) -> bool {
    record
        .get("$type")
        .and_then(Value::as_str)
        .is_some_and(|t| PLAY_COLLECTIONS.contains(&t))
}

/// Read every play record from a repository CAR file, decoded as
/// JSON values. Records that fail to decode are dropped.
pub async fn read_plays(car_path: &str) -> Result<Vec<serde_json::Value>, String> {
    let reader = tokio::io::BufReader::with_capacity(
        1 << 20,
        tokio::fs::File::open(car_path)
            .await
            .map_err(|e| format!("failed to open {car_path}: {e}"))?,
    );

    // Stream the CAR through repo-stream. The block processor runs on
    // every block as it is read; keeping only play records means the
    // driver buffers a fraction of the raw CAR and the MST walk emits
    // just the plays, in rkey order.
    let driver = DriverBuilder::new()
        .with_mem_limit_mb(MEM_LIMIT_MB)
        .with_block_processor(|block| {
            let keep = serde_ipld_dagcbor::from_slice::<Value>(block.as_slice())
                .is_ok_and(|record| is_play_record(&record));
            if keep { block } else { Vec::new() }
        })
        .load_car(reader)
        .await
        .map_err(|e| format!("failed to read CAR file: {e}"))?;

    // The current CAR fits in memory; keep the disk spill path so the
    // pipeline degrades gracefully if the repo outgrows MEM_LIMIT_MB.
    let mut plays = Vec::new();
    match driver {
        Driver::Memory(_commit, mut driver) => {
            while let Some(chunk) = driver
                .next_chunk(256)
                .await
                .map_err(|e| format!("failed to walk MST: {e}"))?
            {
                collect_plays(chunk, &mut plays);
            }
        }
        Driver::Disk(need_disk) => {
            let store = DiskBuilder::new()
                .open(std::env::temp_dir().join(format!("parse-plays-{}.db", std::process::id())))
                .await
                .map_err(|e| format!("failed to open disk store: {e}"))?;
            let (_commit, mut driver) = need_disk
                .finish_loading(store)
                .await
                .map_err(|e| format!("failed to finish loading CAR: {e}"))?;
            while let Some(chunk) = driver
                .next_chunk(256)
                .await
                .map_err(|e| format!("failed to walk MST: {e}"))?
            {
                collect_plays(chunk, &mut plays);
            }
        }
    }
    Ok(plays)
}

/// Push the play records of one emitted chunk; blocks filtered out by
/// the processor (empty data) and records that fail to decode are
/// dropped.
fn collect_plays(chunk: Vec<repo_stream::Output>, plays: &mut Vec<serde_json::Value>) {
    for output in chunk {
        if output.data.is_empty() {
            continue; // filtered-out block
        }
        if let Ok(record) = serde_ipld_dagcbor::from_slice::<Value>(output.data.as_slice()) {
            plays.push(record);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn is_play_record_filters_by_type() {
        assert!(is_play_record(&json!({
            "$type": "fm.teal.feed.play",
            "trackName": "Flute",
        })));
        // Historical alpha plays count toward stats too.
        assert!(is_play_record(&json!({
            "$type": "fm.teal.alpha.feed.play",
            "trackName": "Old Flute",
        })));
        assert!(!is_play_record(&json!({
            "$type": "app.bsky.feed.post",
            "text": "hi",
        })));
        assert!(!is_play_record(&json!({ "trackName": "no type" })));
        assert!(!is_play_record(&json!([1, 2, 3])));
        assert!(!is_play_record(&json!("string")));
    }
}
