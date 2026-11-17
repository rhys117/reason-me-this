# reason_me_this

The Ruby client an app uses to call Reason Me This (reason-me-this.com) over HTTP. `examples/commissions` is a small
Rails app that shows it in use.

## Must follow

- Never commit to `main`. Work on a feature branch.
- Commit often using conventional commits. Feature and refactor commits are always separate.
- Do not add an AI co-author line to commits.
- No em-dashes in prose (README, commit bodies, docs, UI copy).
- No comments unless they explain something non-obvious. No dead code.
- Run `bundle exec rubocop -a` and `bundle exec rspec` before committing, here and in `examples/commissions`
  when it changed. There are no hooks to do it for you.

## Design

Apply Beck's four rules of simple design, in order: passes the tests, reveals intention, no duplication,
fewest elements.

Work in vertical slices: one failing spec, the simplest code to pass it, commit, then decide the next spec
from what you learned. After a feature works, look for duplication and drifted names and commit the cleanup
separately.

## Boundaries

- Zero runtime dependencies beyond the standard library (`net/http`, `json`, `bigdecimal`). Never add the
  engine's gems to the gemspec or the default `Gemfile`: they are licensed separately and may not be
  installed.
- Nothing here names the engine or calls it: not code, prose, specs or tracked gemfiles. A client given an
  `engine` requires `reason_me_this/engines/NAME`, a file the engine's own package provides, which registers
  a connection with `ReasonMeThis::Engines` that answers as the service would. The specs tagged `:engine`
  are that connection's contract and run with `BUNDLE_GEMFILE=gemfiles/engine.gemfile`, an untracked
  gemfile of your own that adds the engine; run both bundles before committing.
- The service's HTTP contract is fixed: the client adapts to it, never the other way.
- Numbers stay exact both ways: a `BigDecimal` fact goes out as a JSON number literal (`JSON::Fragment`),
  and numeric strings in answers come back as `BigDecimal`.
- Unit specs use an injected fake connection. Only `spec/reason_me_this/connection_spec.rb` opens a real
  socket.
