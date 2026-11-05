# Commissions

A small Rails app that shows a sales rep's commission statement by quarter, worked out by Reason Me This
from the rep's deals with `reason_me_this`.

| Piece | What it shows |
| --- | --- |
| `app/models/rep.rb` | `reasons :statement` builds the facts from the rep's deals, cancellations and quarter targets |
| Save this statement | `rep.statement!(year)` writes each quarter into `quarter_statements` and keeps a receipt (`rails g reason_me_this:receipts`) |
| `Deal#to_fact`, `QuarterTarget#to_fact` | each record as the fact the `sales_commission` blueprint reads |
| `RepsController#show` | the statement for a year, or the error in plain words |
| `config/initializers/reason_me_this.rb` | the client, configured from the environment |
| `db/seeds.rb` | Avery Quinn's year: the full-year case in the blueprint's `cases.yml` |
| `spec/` | runs offline: a fake connection answers with that case's outputs |

## Run it against a service

Publish the engine's `sales_commission` blueprint on Reason Me This, then:

```sh
bundle install
bin/rails db:prepare db:seed
RMT_API_URL=http://localhost:3000/api RMT_API_KEY=your-key bin/rails server -p 3001
```

Open http://localhost:3001 and pick Avery Quinn: the year pays $55,830.

## Test it

```sh
bundle exec rspec
bundle exec rubocop
```
