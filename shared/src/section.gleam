import lustre/attribute.{attribute, class, id}
import lustre/element.{type Element, text}
import lustre/element/html.{div, h2}

/// Wrap a titled list of items in the section frame used by plays/repos.
///
/// When `stale` is `True` the section root gets `data-stale="true"`. The
/// client toggles this off once its fetch resolves, and back on for the
/// next poll cycle. The CSS in `priv/static/style.css` keys off
/// `.section[data-stale="true"]` to render a pulsing dot in the header.
pub fn section(
  title: String,
  id_str: String,
  stale: Bool,
  items: List(Element(msg)),
) -> Element(msg) {
  let attrs = case stale {
    True -> [id(id_str), class("section"), attribute("data-stale", "true")]
    False -> [id(id_str), class("section")]
  }
  div(attrs, [h2([], [text(title)]), ..items])
}
