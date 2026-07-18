import gleam/list
import gleam/string

pub fn extract_field(
  lines: List(String),
  prefix: String,
  default: String,
) -> String {
  case list.find(lines, fn(line) { string.starts_with(line, prefix) }) {
    Ok(line) ->
      line
      |> string.drop_start(string.length(prefix))
      |> string.trim
    Error(Nil) -> default
  }
}
