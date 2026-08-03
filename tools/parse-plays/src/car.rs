//! CAR file → play records (jacquard I/O).

use jacquard_common::IntoStatic;
use jacquard_common::types::string::Nsid;
use jacquard_repo::car::reader::{read_car, read_car_header};
use jacquard_repo::storage::MemoryBlockStore;
use jacquard_repo::{BlockStore, Repository};
use smol_str::SmolStr;
use std::sync::Arc;

const PLAY_COLLECTION: &str = "fm.teal.alpha.feed.play";

/// Read every play record from a repository CAR file, decoded as
/// JSON values. Records that fail to decode are dropped.
pub async fn read_plays(car_path: &str) -> Result<Vec<serde_json::Value>, String> {
    let store = Arc::new(MemoryBlockStore::new());
    store
        .put_many(
            read_car(car_path)
                .await
                .map_err(|e| format!("failed to read CAR file: {e}"))?,
        )
        .await
        .map_err(|e| format!("failed to load blocks into store: {e}"))?;

    let roots = read_car_header(car_path)
        .await
        .map_err(|e| format!("failed to read CAR header: {e}"))?;

    let collection = Nsid::new(PLAY_COLLECTION)
        .expect("invalid collection NSID")
        .into_static();

    let entries = Repository::<SmolStr, _>::from_commit(
        store.clone(),
        roots.first().ok_or("CAR file has no roots")?,
    )
    .await
    .map_err(|e| format!("failed to load repository from commit: {e}"))?
    .list_collection_data(&collection)
    .await
    .map_err(|e| format!("failed to list play records: {e}"))?;

    let mut plays = Vec::new();
    for (_, _, data) in &entries {
        if let Ok(record) = serde_ipld_dagcbor::from_slice::<serde_json::Value>(data) {
            plays.push(record);
        }
    }
    Ok(plays)
}
