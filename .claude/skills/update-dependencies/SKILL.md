---
name: update-dependencies
description: Maintenance upgrade of this gem's whole dependency stack (Bundler, Ruby gems, Rust crates such as magnus/rb-sys/ndarray, Rust edition, minimum Ruby version, CI matrix, docs), done piece by piece on a work branch with one atomic, reviewable commit per step. Use when asked to update/upgrade dependencies, bump magnus/ndarray/rb-sys, support a new Ruby or Rust release, or do routine maintenance of the gem.
---

# Updating the ndarray gem's dependencies

The goal is a **linear history of small commits**, one per logical upgrade, each of which builds and passes `bundle exec rake` (compile + spec + standard), so the PR can be reviewed commit by commit.

Do the steps in the order below. Skip a step when there is nothing to update, and say so in the final summary. Do not commit a step that is unrelated to dependencies; open a separate branch for that.

## Conventions used throughout

- Follow AGENTS.md › Commands, in particular *Build output and checks*: log the build to a file and grep it, lint with `rake standard`, and force `clippy` past its cache. `bundle exec rake spec` does **not** recompile, so after Rust changes always run the full `bundle exec rake`.
- **Verify every step:** before each commit, run `bundle exec rake` and `cargo clippy`, and check `git diff --stat` to confirm that only the expected files changed.
- Commit messages: imperative subject (`Bump magnus from 0.6 to 0.9`), with a short body that explains *why* when it is not obvious. No AI attribution trailers.

## 0. Preparation

```bash
git fetch origin
git status --short                      # must be clean (untracked junk is fine)
git switch -c update-dependencies-$(date +%Y-%m) origin/master
ruby -v; bundle -v; rustc --version; cargo --version
```

Never work on `master` (see AGENTS.md › Workflow).

Run a **baseline** `bundle exec rake` before changing anything. If it already fails, record the reason. A new Ruby or Rust release often breaks the build with no code change, and that tells you which upgrade is mandatory. For example, an old `rb-sys` crate fails with a newer Ruby, and an old `magnus` stops compiling when Ruby changes its internal structs.

Optionally run `rustup update` (this is not committed).

## 1. Bundler

```bash
gem list -r '^bundler$'                 # latest STABLE version on rubygems.org
bundle -v                               # the locally active version may be a beta!
gem install bundler -v X.Y.Z --no-document
bundle update --bundler=X.Y.Z           # always pass the version explicitly
git diff Gemfile.lock                   # only the BUNDLED WITH line may change
```

Never lock a prerelease (`.beta`, `.rc`). A bare `bundle update --bundler` locks whichever Bundler is active locally, and that may be a beta.

Commit: `Bundle update --bundler to X.Y.Z`.

## 2. Ruby gems within current constraints

```bash
bundle outdated                         # overview
bundle update
git diff Gemfile.lock | grep -E '^[+-] '
bundle exec rake
```

Commit: `Bundle update`.

If `bundle outdated` shows a gem held back by a `Gemfile` or gemspec constraint (for example `standard ~> 1.3` or `rspec ~> 3.0`), relax that constraint in a **separate commit per gem**, together with any code or lint fixes it requires.

Adding, removing or swapping a development gem (for example a debugger) is also its own commit, with the gem placed in the right `group`.

## 3. Rust crates within current constraints

```bash
cargo update --dry-run                  # preview
cargo update
```

**Check that the `rb-sys` crate in `Cargo.lock` matches the `rb_sys` gem in `Gemfile.lock`:**

```bash
grep -A1 'name = "rb-sys"' Cargo.lock; grep ' rb_sys ' Gemfile.lock
```

Commit only `Cargo.lock`: `Cargo update (semver-compatible)`.

If this step cannot build alone because a crate still needs a major bump (step 4), say so in the commit body. If reviewers need every commit to build, squash it into the commit that fixes the build instead.

## 4. Major bumps of direct crates, one crate per commit

The direct dependencies are listed in `ext/ruby_ndarray_rust_ext/Cargo.toml` (currently `magnus` and `ndarray`). To find the latest version of each:

```bash
cargo search magnus --limit 1
cargo search ndarray --limit 1
```

For each crate:

1. Edit the version in `ext/ruby_ndarray_rust_ext/Cargo.toml`.
2. Run `cargo build 2>&1 | grep -E '^(error|warning)|-->'`.
3. Fix the code depending on what you find:
   - **Compile errors:** fix them in the **same** commit as the bump, so the commit builds.
   - **Deprecation warnings only:** commit the bump alone (`Bump <crate> from A to B`). Then fix the deprecations in a **separate** commit (`Replace deprecated <crate> ...`).
4. Run `bundle exec rake` and `cargo clippy`, then commit.

If the code change alters a pattern described in AGENTS.md › Architecture (for example how errors are raised from Rust), update AGENTS.md in the same commit.

Known migration notes:

- **magnus ≥ 0.7:** the free functions `magnus::exception::*` are deprecated. Use `ruby.exception_arg_error()`, which means the Rust method receives `ruby: &Ruby` as its first argument. `function!`/`method!` handle that argument automatically, and the Ruby-side arity does not change.
- **magnus/rb-sys and new Ruby versions:** a new Ruby major or minor release usually needs the latest `rb-sys` *and* a `magnus` release that supports it.

## 5. Rust edition and minimum Rust version

```bash
cargo new --help | grep -A1 -- '--edition'   # editions known to the toolchain
```

When a newer edition is available:

1. Set `edition` in `ext/ruby_ndarray_rust_ext/Cargo.toml`.
2. Set `rust-version` to the minimum rustc that edition needs (2024 needs 1.85).
3. Run `cargo fmt`, because the style edition can reorder imports.
4. Update the Rust prerequisite in `README.md`.

All of this goes in one commit: `Move Rust crate to edition YYYY`.

## 6. Supported Ruby versions and CI

When raising the minimum Ruby, change all of these in one commit (`Require Ruby >= X.Y`):

- `ndarray.gemspec` → `required_ruby_version`
- `.standard.yml` → `ruby_version`. Check that RuboCop knows that version:
  `bundle exec ruby -e 'require "standard"; p RuboCop::TargetRuby.const_get(:KNOWN_RUBIES).last(3)'`
- `.github/workflows/main.yml` → Ruby matrix (supported versions plus `ruby-head`). Do not pin an old `rubygems:` version, because that downgrades the RubyGems shipped with a newer Ruby.
- `README.md` (Prerequisites) and `AGENTS.md` (Project line, the `standard` target comment)

GitHub Actions versions in the workflow (`actions/checkout@vN`, `oxidize-rb/actions/...@vN`) can be bumped in their own commit.

## 7. Stale-reference sweep

```bash
git grep -nE '<old version strings>' -- ':!*.lock'
```

Look for old Ruby, Rust and crate versions in docs, the gemspec, CI and `sig/`. If a stale reference belongs to an earlier commit in this branch, fix it with a fixup commit (see below) rather than a trailing "fix docs" commit.

## 8. Final verification

```bash
git log --oneline origin/master..       # review the story
bundle exec rake && cargo clippy -- -D warnings && cargo fmt --check
# Prove that every commit builds and passes (slow: recompiles each commit):
git rebase --exec 'bundle exec rake > /dev/null 2>&1' origin/master
```

The only commit allowed to fail `--exec` is a lockfile-only step that is documented as such (step 3).

## Fixing an earlier commit in the branch

As long as the branch is not merged (check with `git status -sb` and `git log origin/master..`), keep the history clean by amending the right commit:

```bash
git commit --fixup=<sha-of-target-commit>        # or: git commit -m "fixup! <exact subject>"
GIT_SEQUENCE_EDITOR=true git rebase -i --autosquash origin/master
```

For a larger edit of an old commit:

```bash
git branch backup/<name>                          # safety net
GIT_SEQUENCE_EDITOR="sed -i 's/^pick <sha>/edit <sha>/'" git rebase -i <sha>~1
# ... change files, git add, git commit --amend ...
GIT_EDITOR=true git rebase --continue
git diff backup/<name>                            # must show only the intended change
```

If a fixup touches lines next to lines changed by a later commit (for example two adjacent README lines), the rebase stops twice: once for the fixup and once for the later commit. Resolve each conflict to the state that is correct **at that point in history**.

If the branch was already pushed, rewriting history needs `git push --force-with-lease`. Ask the user before doing it.

## Finish

Push and open the PR only when the user asks:

```bash
git push -u origin <branch>
gh pr create --base master --fill
```

The PR description should list the commits and their purpose. It should also call out anything a reviewer must know: commits that do not build on their own, behavior changes, dropped Ruby or Rust versions, and new minimum toolchain versions.
