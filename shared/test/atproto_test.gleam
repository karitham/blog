import atproto.{type DecodedRecord, DecodedRecord}
import gen/repo.{type Repo}
import gleam/option.{type Option, None, Some}
import gleeunit/should

// --- rkey_from_uri ---

pub fn rkey_from_uri_extracts_rkey_test() {
  atproto.rkey_from_uri("at://did:plc:abc/sh.tangled.repo/blog")
  |> should.equal(Ok("blog"))
}

pub fn rkey_from_uri_handles_handle_authority_test() {
  atproto.rkey_from_uri("at://karitham.dev/sh.tangled.repo/karitham_blog")
  |> should.equal(Ok("karitham_blog"))
}

// --- decode_repos ---

pub fn decode_repos_preserves_uri_test() {
  let body =
    "{\"records\":[{
      \"cid\": \"bafy1\",
      \"uri\": \"at://did:plc:abc/sh.tangled.repo/blog\",
      \"value\": {
        \"name\": \"\",
        \"repoDid\": \"did:plc:abc\",
        \"createdAt\": \"2026-01-15T10:00:00Z\"
      }
    }]}"
  let assert Ok(records) = atproto.decode_repos(body)
  let assert [rec] = records
  rec.uri |> should.equal("at://did:plc:abc/sh.tangled.repo/blog")
  rec.value.repo_did |> should.equal("did:plc:abc")
}

pub fn decode_repos_drops_records_with_invalid_value_test() {
  let body =
    "{\"records\":[
      {\"cid\": \"bafy1\", \"uri\": \"at://x/y/a\", \"value\": {
        \"name\": \"good\", \"repoDid\": \"did:plc:a\", \"createdAt\": \"2026-01-01T00:00:00Z\"
      }},
      {\"cid\": \"bafy2\", \"uri\": \"at://x/y/b\", \"value\": \"not an object\"}
    ]}"
  let assert Ok(records) = atproto.decode_repos(body)
  let assert [kept] = records
  kept.uri |> should.equal("at://x/y/a")
  kept.value.name |> should.equal(Some("good"))
}
