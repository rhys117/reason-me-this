# Commissions

A small Rails app that shows a sales rep's commission statement by quarter, worked out by a Reckoning
service from the rep's deals with `reckoning-client`.

| Piece | What it shows |
| --- | --- |
| `app/models/rep.rb` | `reckons :statement` builds the facts from the rep's deals, cancellations and quarter targets |
| `Deal#to_fact`, `QuarterTarget#to_fact` | each record as the fact the `sales_commission` blueprint reads |
| `RepsController#show` | the statement for a year, or the error in plain words |
| `config/initializers/reckoning.rb` | the client, configured from the environment |
| `db/seeds.rb` | Avery Quinn's year: the full-year case in the blueprint's `cases.yml` |
| `spec/` | runs offline: a fake connection answers with that case's outputs |

## Run it against a service

Publish the engine's `sales_commission` blueprint on a Reckoning service, then:

```sh
bundle install
bin/rails db:prepare db:seed
RECKONING_API_URL=http://localhost:3000/api RECKONING_API_KEY=your-key bin/rails server -p 3001
```

Open http://localhost:3001 and pick Avery Quinn: the year pays $55,830.

## Test it

```sh
bundle exec rspec
bundle exec rubocop
```
