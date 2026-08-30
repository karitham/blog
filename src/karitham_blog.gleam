import argv
import build
import cli
import gleam/io
import gleam/string

/// Entry point. Dispatches to the right subcommand based on argv.
///   gleam run           → build (default)
///   gleam run build     → build the SSG
///   gleam run new <slug> → scaffold a new post
///   gleam run help      → usage
pub fn main() {
  case argv.load().arguments {
    [] | ["build"] -> build.build()
    ["new", ..rest] -> cli.new_post(string.join(rest, " "))
    ["help"] | ["-h"] | ["--help"] -> cli.print_usage()
    other -> {
      cli.print_usage()
      io.println("")
      io.println("Unknown command: " <> string.join(other, " "))
      panic as "unknown subcommand"
    }
  }
}
