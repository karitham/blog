import data/image_ext
import gleeunit/should

pub fn ext_png_test() {
  image_ext.ext_for_content_type("image/png") |> should.equal("png")
}

pub fn ext_webp_test() {
  image_ext.ext_for_content_type("image/webp") |> should.equal("webp")
}

pub fn ext_gif_test() {
  image_ext.ext_for_content_type("image/gif") |> should.equal("gif")
}

pub fn ext_unknown_falls_back_to_jpg_test() {
  image_ext.ext_for_content_type("application/octet-stream")
  |> should.equal("jpg")
}

pub fn ext_uppercase_is_lowercased_test() {
  image_ext.ext_for_content_type("image/PNG") |> should.equal("png")
}

pub fn ext_svg_falls_back_test() {
  // SVG files are served but deliberately not mirrored with an .svg
  // extension; the default jpg keeps the old filename scheme stable.
  image_ext.ext_for_content_type("image/svg+xml") |> should.equal("jpg")
}
