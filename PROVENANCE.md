# Provenance

This repository is a **read-only shallow mirror** of the `op-revm` crate: a
snapshot of a single upstream commit, without upstream git history. It exists
so the crate can be used as a lightweight cargo git dependency instead of
depending on the huge Optimism monorepo.

| | |
|---|---|
| Upstream repository | <https://github.com/ethereum-optimism/optimism> |
| Upstream path | `rust/op-revm` |
| Upstream commit | `b40d2ce097b928fe1a4ec79a8a1925eb231c675e` (tag `op-reth/v2.4.0`) |
| Crate version | `20.0.0` |

All files are verbatim copies of upstream, with two exceptions:

- `Cargo.toml` — the monorepo's `workspace = true` inheritances are flattened
  to concrete values (see below) so the crate builds standalone.
- `PROVENANCE.md`, `verify.sh`, and `.gitignore` — added by this mirror.

Run `./verify.sh` to re-check byte-identity against the pinned upstream
commit (it prints the `Cargo.toml` diff for review and fails on any other
divergence).

## How the flattened `Cargo.toml` values are obtained

In the monorepo, the crate's manifest inherits shared values from the
workspace root `Cargo.toml` (at `rust/Cargo.toml` relative to the monorepo):

- every dependency declared as `foo.workspace = true` (or
  `foo = { workspace = true, ... }`) resolves to the entry for `foo` in the
  workspace root's `[workspace.dependencies]` table;
- every `[package]` field declared as `<field>.workspace = true` (edition,
  license, authors, ...) resolves to the same field in the workspace root's
  `[workspace.package]` table.

To flatten, copy each inherited value from those tables **at the same pinned
upstream commit** into this crate's manifest, merging any locally declared
`features`/`default-features` with the workspace entry's. Never carry values
over from a previously flattened manifest: the workspace's versions move
between commits.

## Updating to a new upstream commit

The mirror is a snapshot per upstream commit: each mirror commit corresponds
to exactly one upstream commit, named in its message. The commit message is
only a claim — `verify.sh` is the proof — so verification runs *before*
committing, and anyone can re-run it against any mirror commit later.

1. **Pick the upstream commit.** Prefer a commit matching an upstream release
   tag (e.g. `op-reth/vX.Y.Z`) over an arbitrary tip of `main`, and record
   which tag it corresponds to.
2. **Replace the snapshot wholesale.** Delete everything except
   `PROVENANCE.md`, `verify.sh`, `.gitignore`, and `.git/`, then copy in
   `rust/op-revm` from the new upstream commit. Deleting first matters:
   copying over the top silently keeps files upstream has removed.
3. **Re-flatten `Cargo.toml`** from the new commit's workspace root, as
   described above. This is the only manual, error-prone step, which is why
   `verify.sh` prints the full `Cargo.toml` diff for review instead of just
   passing it.
4. **Update the pinned commit hash** in `verify.sh` (`COMMIT=`) and in the
   table at the top of this file.
5. **Run `./verify.sh`.** It must report every file byte-identical and show a
   `Cargo.toml` diff containing nothing but the workspace-inheritance
   flattening. Fix anything else before committing.
6. **Commit the snapshot as a single commit** naming the upstream commit hash
   and tag, then **tag the mirror commit** as
   `<upstream release tag>-<upstream sha abbreviation>` (e.g.
   `op-reth-v2.4.0-b40d2ce`). The tag is the human-readable version identity —
   the crate version alone does not distinguish snapshots — while this file
   and `verify.sh` remain the authority for the full upstream hash (tags are
   mutable refs; consumers' lock files pin the exact commit regardless).
   Never mix a snapshot with any other change; if a local patch is ever
   unavoidable, make it a separate, loudly-labeled commit — and reconsider
   whether the mirror should exist at all at that point, since its value is
   being verbatim.
7. **Update the consumer.** Point the dependent repo's `Cargo.toml` `tag` at
   the new mirror tag, so the upstream version is readable from the consumer's
   manifest.
