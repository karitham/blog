import atproto
import gleam/option.{None, Some}
import gleam/string
import gleeunit/should

// --- URL builders ---

pub fn pinned_dids_url_fetches_profile_record_test() {
  let url = atproto.pinned_dids_url()
  url
  |> string.contains("/xrpc/com.atproto.repo.getRecord?")
  |> should.be_true()
  url
  |> string.contains("collection=org.tangled.actor.profile")
  |> should.be_true()
  url |> string.contains("rkey=self") |> should.be_true()
}

pub fn repos_url_repeats_dids_test() {
  let url = atproto.repos_url(["did:plc:one", "did:plc:two"])
  url
  |> string.contains("dids=did%3Aplc%3Aone&dids=did%3Aplc%3Atwo")
  |> should.be_true()
  url
  |> string.contains("/xrpc/org.tangled.repo.getReposByRepoDids?")
  |> should.be_true()
}

// --- decode_repos ---

pub fn decode_repos_preserves_uri_and_manifest_test() {
  let body =
    "{\"items\":[{
      \"cid\": \"bafy1\",
      \"uri\": \"at://did:plc:repo/org.tangled.repo.manifest/self\",
      \"value\": {
        \"declaration\": {\"owner\": \"did:plc:owner\", \"name\": \"site\"},
        \"createdAt\": \"2026-01-15T10:00:00Z\",
        \"description\": \"desc\",
        \"topics\": [\"gleam\"]
      }
    }]}"
  let assert Ok(#(records, drops)) = atproto.decode_repos(body)
  drops |> should.equal(0)
  let assert [rec] = records
  rec.uri
  |> should.equal("at://did:plc:repo/org.tangled.repo.manifest/self")
  rec.value.declaration.owner |> should.equal("did:plc:owner")
  rec.value.declaration.name |> should.equal("site")
  rec.value.description |> should.equal(Some("desc"))
}

pub fn decode_repos_drops_records_with_invalid_value_test() {
  let body =
    "{\"items\":[
      {\"cid\": \"bafy1\", \"uri\": \"at://did:plc:good/org.tangled.repo.manifest/self\",
       \"value\": {\"declaration\": {\"owner\": \"did:plc:owner\", \"name\": \"good\"},
                   \"createdAt\": \"2026-01-01T00:00:00Z\"}},
      {\"cid\": \"bafy2\", \"uri\": \"at://did:plc:bad/org.tangled.repo.manifest/self\",
       \"value\": \"not an object\"}
    ]}"
  let assert Ok(#(records, drops)) = atproto.decode_repos(body)
  drops |> should.equal(1)
  let assert [kept] = records
  kept.value.declaration.name |> should.equal("good")
}

pub fn decode_repos_empty_items_test() {
  let assert Ok(#(records, drops)) = atproto.decode_repos("{\"items\":[]}")
  records |> should.equal([])
  drops |> should.equal(0)
}

// --- decode_actor_profile ---

pub fn decode_actor_profile_decodes_pins_test() {
  let body =
    "{\"uri\": \"at://did:plc:self/org.tangled.actor.profile/self\",
      \"cid\": \"bafy1\",
      \"value\": {
        \"pinnedRepositories\": [\"did:plc:one\", \"did:plc:two\"],
        \"description\": \"ignored\"
      }}"
  let assert Ok(profile) = atproto.decode_actor_profile(body)
  profile.pinned_repositories
  |> should.equal(Some(["did:plc:one", "did:plc:two"]))
}

pub fn decode_actor_profile_missing_pins_test() {
  let body = "{\"value\": {\"description\": \"no pins\"}}"
  let assert Ok(profile) = atproto.decode_actor_profile(body)
  profile.pinned_repositories |> should.equal(None)
}

pub fn decode_actor_profile_requires_value_test() {
  atproto.decode_actor_profile("{\"uri\": \"at://x\"}") |> should.be_error()
}
