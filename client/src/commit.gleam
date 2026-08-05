//// The DOM operations the pure pipeline can produce. The interpreter
//// (`app.gleam`) maps each to a `browser.*` call; keeping them as
//// data means the planning half is unit-testable without a browser.

pub type Command {
  ReplaceHtml(id: String, html: String)
  SetAttr(id: String, name: String, value: String)
  RemoveAttr(id: String, name: String)
  LocalizeDates
  RewriteRemoteImages
}
