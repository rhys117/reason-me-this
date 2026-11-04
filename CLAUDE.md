# reckoning-client

The Ruby SDK an app uses to call a hosted Reckoning service over HTTP. `examples/commissions` is a small
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

- Zero runtime dependencies beyond the standard library (`net/http`, `json`, `bigdecimal`). Never depend on
  the `reckoning` engine gem; this gem only speaks HTTP.
- The service's HTTP contract is fixed: the client adapts to it, never the other way.
- Numbers stay exact both ways: a `BigDecimal` fact goes out as a JSON number literal (`JSON::Fragment`),
  and numeric strings in answers come back as `BigDecimal`.
- Unit specs use an injected fake connection. Only `spec/reckoning/client/connection_spec.rb` opens a real
  socket.
