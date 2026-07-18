import argv
import blog_tools
import gleam/io
import gleam/string

/// Entry point. Dispatches to the right subcommand based on argv.
///   gleam run           → build (default)
///   gleam run build     → build the SSG
///   gleam run client    → hint for building the client
///   gleam run new <slug> → scaffold a new post
///   gleam run help      → usage
pub fn main() {
  case argv.load().arguments {
    [] | ["build"] -> blog_tools.build_site()
    ["client"] -> blog_tools.build_client()
    ["new", ..rest] -> blog_tools.new_post(string.join(rest, " "))
    ["help"] | ["-h"] | ["--help"] -> blog_tools.print_usage()
    other -> {
      blog_tools.print_usage()
      io.println("")
      io.println("Unknown command: " <> string.join(other, " "))
      panic as "unknown subcommand"
    }
  }
}
