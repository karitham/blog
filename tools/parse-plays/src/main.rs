use jacquard_common::IntoStatic;
use jacquard_common::types::string::Nsid;
use jacquard_repo::car::reader::{read_car, read_car_header};
use jacquard_repo::storage::MemoryBlockStore;
use jacquard_repo::{BlockStore, Repository};
use smol_str::SmolStr;
use std::sync::Arc;

const PLAY_COLLECTION: &str = "fm.teal.alpha.feed.play";

#[tokio::main]
async fn main() {
    let car_path = std::env::args()
        .nth(1)
        .expect("Usage: parse-plays <car-file>");

    let store = Arc::new(MemoryBlockStore::new());

    store
        .put_many(read_car(&car_path).await.expect("failed to read CAR file"))
        .await
        .expect("failed to load blocks into store");

    let roots = read_car_header(&car_path)
        .await
        .expect("failed to read CAR header");

    let collection = Nsid::new(PLAY_COLLECTION)
        .expect("invalid collection NSID")
        .into_static();

    let entries = Repository::<SmolStr, _>::from_commit(
        store.clone(),
        roots.first().expect("CAR file has no roots"),
    )
    .await
    .expect("failed to load repository from commit")
    .list_collection_data(&collection)
    .await
    .expect("failed to list play records");

    let mut plays = Vec::new();
    for (_, _, data) in &entries {
        if let Ok(record) = serde_ipld_dagcbor::from_slice::<serde_json::Value>(data) {
            plays.push(record);
        }
    }

    serde_json::to_writer(std::io::stdout(), &plays).expect("failed to write JSON");
}
