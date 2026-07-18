// Vendored highlight.js extension: register nushell and gleam grammars,
// then highlight all code blocks on the page.
//
// highlight.js core (highlight.min.js) is loaded first via <script src>.
// hljs is exposed as a global. mork emits <pre><code class="language-X">.

const hljs = window.hljs;

// --- Gleam grammar (extracted from npm package highlightjs-gleam@0.2.2) ---
hljs.registerLanguage("gleam", function (h) {
  const KEYWORDS =
    "as assert case const external fn if import let " +
    "opaque pub todo try tuple type";
  const NAME = {
    className: "variable",
    begin: "\\b[a-z][a-z0-9_]*\\b",
    relevance: 0,
  };
  const DISCARD_NAME = {
    className: "comment",
    begin: "\\b_[a-z][a-z0-9_]*\\b",
    relevance: 0,
  };
  const NUMBER = {
    className: "number",
    variants: [
      { begin: "\\b0b([01_]+)" },
      { begin: "\\b0o([0-7_]+)" },
      { begin: "\\b0x([A-Fa-f0-9_]+)" },
      {
        begin: "\\b(\\d[\\d_]*(\\.[0-9_]+)?([eE][+-]?[0-9_]+)?)",
      },
    ],
    relevance: 0,
  };
  return {
    name: "Gleam",
    aliases: ["gleam"],
    contains: [
      h.C_LINE_COMMENT_MODE,
      {
        className: "string",
        variants: [{ begin: /"/, end: /"/ }],
        contains: [h.BACKSLASH_ESCAPE],
        relevance: 0,
      },
      {
        begin: "<<",
        end: ">>",
        contains: [
          {
            className: "keyword",
            beginKeywords:
              "binary bytes int float bit_string bits utf8 utf16 utf32 " +
              "utf8_codepoint utf16_codepoint utf32_codepoint signed unsigned " +
              "big little native unit size",
          },
          NUMBER,
          NAME,
          DISCARD_NAME,
        ],
        relevance: 10,
      },
      {
        className: "function",
        beginKeywords: "fn",
        end: "\\(",
        excludeEnd: true,
        contains: [
          { className: "title", begin: "[a-zA-Z0-9_]\\w*", relevance: 0 },
        ],
      },
      { className: "keyword", beginKeywords: KEYWORDS },
      { className: "title", begin: "\\b[A-Z][A-Za-z0-9_]*\\b", relevance: 0 },
      {
        className: "operator",
        begin: "(\\+\\.|-\\.|\\*\\.|/\\.|<\\.|>\\.)",
        relevance: 10,
      },
      {
        className: "operator",
        begin: "(->|\\|>|<<|>>|\\+|-|\\*|/|>=|<=|<|<|%|\\.\\.|\\|=|==|!=)",
        relevance: 0,
      },
      NUMBER,
      NAME,
      DISCARD_NAME,
    ],
  };
});

// --- Nushell grammar (minimal: keywords, strings, vars, numbers, commands) ---
hljs.registerLanguage("nu", function (h) {
  const KEYWORDS = [
    "let",
    "mut",
    "def",
    "if",
    "else",
    "match",
    "while",
    "for",
    "in",
    "loop",
    "break",
    "continue",
    "return",
    "try",
    "catch",
    "do",
    "echo",
    "print",
    "source",
    "use",
    "module",
    "export",
    "extern",
    "alias",
    "const",
    "pub",
    "each",
    "where",
    "reduce",
    "filter",
    "sort-by",
    "group-by",
    "range",
    "any",
    "all",
    "wrap",
    "transpose",
    "pivot",
    "flatten",
    "skip",
    "take",
    "first",
    "last",
    "get",
    "select",
    "update",
    "insert",
    "append",
    "prepend",
    "length",
    "size",
    "empty",
    "describe",
    "version",
    "history",
  ];
  const SUB_COMMANDS = [
    "str",
    "path",
    "list",
    "into",
    "from",
    "to",
    "save",
    "open",
    "load",
    "http",
    "http get",
    "http post",
    "items",
    "columns",
    "lines",
    "parse",
    "format",
    "ansi",
    "bytes",
    "binary",
    "int",
    "float",
    "bool",
    "date",
    "duration",
    "env",
    "config",
    "nu-check",
    "expand",
    "collect",
    "compact",
    "default",
    "detect",
    "split",
    "join",
    "replace",
    "trim",
    "contains",
    "starts-with",
    "ends-with",
    "downcase",
    "upcase",
    "ansi strip",
    "ansi link",
    "length",
  ];
  return {
    name: "Nushell",
    aliases: ["nu", "nushell"],
    case_insensitive: false,
    contains: [
      h.HASH_COMMENT_MODE,
      {
        // interpolated strings: $"..." with optional (expr) interpolation
        className: "string",
        begin: /\$"/,
        end: /"/,
        contains: [
          {
            className: "subst",
            begin: /\(/,
            end: /\)/,
          },
          h.BACKSLASH_ESCAPE,
        ],
      },
      {
        // raw strings: r#'...'#
        className: "string",
        begin: /r#'/,
        end: /'#/,
      },
      {
        // single-quoted literal strings
        className: "string",
        begin: /'/,
        end: /'/,
      },
      // double-quoted strings without interpolation
      {
        className: "string",
        begin: /"/,
        end: /"/,
        contains: [h.BACKSLASH_ESCAPE],
        relevance: 0,
      },
      {
        // variables: $name
        className: "variable",
        begin: /\$[a-zA-Z_][a-zA-Z0-9_-]*/,
        relevance: 5,
      },
      {
        // env var prefix: $env.NAME
        className: "variable",
        begin: /\$env\.[A-Z_][A-Z0-9_]*/,
        relevance: 0,
      },
      {
        // numbers
        className: "number",
        begin:
          /\b(\d[\d_]*(\.[0-9_]+)?([eE][+-]?[0-9_]+)?|0b[01_]+|0o[0-7_]+|0x[0-9a-fA-F_]+)\b/,
        relevance: 0,
      },
      {
        // flags: --flag or -f
        className: "meta",
        begin: /--?[a-zA-Z][a-zA-Z0-9_-]*/,
        relevance: 0,
      },
      {
        // type names (capitalized identifiers)
        className: "type",
        begin: /\b[A-Z][a-zA-Z0-9_]*\b/,
        relevance: 0,
      },
      {
        // keywords
        className: "keyword",
        beginKeywords: KEYWORDS.join(" "),
      },
      {
        // subcommands (str, path, etc.) - colored as builtins
        className: "built_in",
        begin: SUB_COMMANDS.map((c) => c.replace(/-/g, "\\-")).join("|"),
        relevance: 0,
      },
    ],
  };
});

// Map mork's "language-nu" → hljs "nu" (mork already uses language-nu, so this is
// already correct, but alias for safety).
hljs.registerAliases("nushell", { languageName: "nu" });

// Run on DOM ready.
function init() {
  if (window.hljs && typeof window.hljs.highlightAll === "function") {
    window.hljs.highlightAll();
  }
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", init);
} else {
  init();
}
