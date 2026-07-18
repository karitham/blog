import dynamic
import gleeunit/should

pub fn strip_fragment_empty_test() {
  dynamic.strip_fragment_comments("") |> should.equal("")
}

pub fn strip_fragment_passthrough_test() {
  // No markers → unchanged.
  dynamic.strip_fragment_comments("<div>hello</div>")
  |> should.equal("<div>hello</div>")
}

pub fn strip_fragment_open_marker_test() {
  dynamic.strip_fragment_comments("<!-- lustre:fragment --><div>x</div>")
  |> should.equal("<div>x</div>")
}

pub fn strip_fragment_close_marker_test() {
  dynamic.strip_fragment_comments("<div>x</div><!-- /lustre:fragment -->")
  |> should.equal("<div>x</div>")
}

pub fn strip_fragment_both_markers_test() {
  dynamic.strip_fragment_comments(
    "<!-- lustre:fragment --><div>x</div><!-- /lustre:fragment -->",
  )
  |> should.equal("<div>x</div>")
}

pub fn strip_fragment_nested_test() {
  // Multiple fragments in one document — all markers removed.
  dynamic.strip_fragment_comments(
    "<!-- lustre:fragment -->a<!-- /lustre:fragment --><!-- lustre:fragment -->b<!-- /lustre:fragment -->",
  )
  |> should.equal("ab")
}

pub fn strip_fragment_markers_in_text_test() {
  // Marker-like text inside element content (not real markers) is
  // intentionally preserved — strip_fragment_comments does a literal
  // replace, not a regex. This test guards that behavior.
  dynamic.strip_fragment_comments("<p>not a marker: <!-- not-lustre --></p>")
  |> should.equal("<p>not a marker: <!-- not-lustre --></p>")
}
