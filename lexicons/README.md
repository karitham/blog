# Vendored lexicons

Schemas the code generators read. They are vendored, not fetched at build
time, so a build is reproducible and offline unless it is fetching data.

## Tangled

Tangled v1 moved its canonical records from the legacy `sh.tangled.*`
namespace to `org.tangled.*`. The schemas live in
[`tangled.org/tangled.org/core`](https://tangled.org/tangled.org/core/tree/master/lexicons/org/tangled).
These files are field subsets of the canonical schemas at commit
`2ad07b40a0941533cd1afbf0e3f67827bc166e54`:

- `org/tangled/actor/profile.json`: only `pinnedRepositories`, which is
  all the site reads.
- `org/tangled/repo/manifest.json`: `declaration`, `createdAt`,
  `description`, `topics`, and `website`. Repo manifests are owned by
  the repository DID, so the site reads them through the appview
  (`org.tangled.repo.getReposByRepoDids`) rather than the owner's PDS.

When Tangled changes a field the site uses, copy the current canonical
schema, keep the subset narrow, and run `just codegen`. The decoder drop
counts in the build and client logs make a field-shape mismatch visible.
