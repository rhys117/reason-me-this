# reason_me_this

The Ruby client for [Reason Me This](https://reason-me-this.com). It runs, explains, pushes and publishes definitions over HTTP
and keeps every number exact on the way out and on the way back.

It only speaks HTTP: it needs nothing beyond Ruby's standard library and does not load the engine.

## Install

```ruby
gem "reason_me_this"
```

## The rmt CLI

The gem installs `rmt`, which builds, proves, publishes and runs blueprints on the service. It answers in
JSON when its output is not a terminal, so an agent can loop on it, and in text at a terminal.

```sh
export RMT_API_KEY=...                       # from https://reason-me-this.com/app/api_keys
rmt guide                                    # how to build a blueprint
rmt check bill.yml                           # exit 2 while it has problems
rmt test bill.yml cases.yml                  # exit 3 while a case fails
rmt push bill bill.yml cases.yml && rmt publish bill
rmt publish bill --effective-from 2027-01-01 --no-live
echo '{"plan": "flat_rate"}' | rmt run bill --trace
echo '{"plan": "flat_rate"}' | rmt run bill --on 2026-07-01
rmt schema bill --calculation bill           # JSON Schemas of its facts and outputs
rmt run electricity_bill --facts facts.json  # a shipped blueprint, by name
```

`check`, `test` and `run` on a file send its text to the service and save nothing. Exit codes: 0 success,
1 a run failed or no such definition or version, 2 problems, 3 a case failed, 64 usage, 69 the service could
not be reached, 77 the key was refused. `rmt help` lists every command. `RMT_API_URL` points it at another
service. `rmt run` and `rmt schema` take the live version, `--version N` or `draft`, or `--on YYYY-MM-DD` for
the version in effect that day. `rmt publish` takes `--effective-from YYYY-MM-DD` (today by default) and
`--no-live`, which keeps the live version live so the new one waits. `rmt schema` prints JSON even at a
terminal.

## Configure

```ruby
require "reason_me_this"

ReasonMeThis.configure do |config|
  config.url = ENV["RMT_API_URL"]     # https://reason-me-this.com/api
  config.api_key = ENV["RMT_API_KEY"]
end
```

In Rails this belongs in `config/initializers/reason_me_this.rb`.

## Run

```ruby
answer = ReasonMeThis.run("sales_commission@3", facts, calculation: :year)

answer.total_paid        # => BigDecimal("55830")
answer[:by_quarter]      # => [{start: Date(2026-01-01), payout: BigDecimal("5000"), ...}, ...]
answer.to_h
```

| Option | Means |
| --- | --- |
| `calculation:` | which calculation in the definition to run |
| `version:` | a published version number, `"latest"` (the default, the live version) or `"draft"` |
| `on:` | a `Date`: run the version in effect that day, rather than the live one. Not with a version number |
| `trace:` | `true` answers as `explain` does |

`"sales_commission@3"` pins the name to published version 3. A `version:` given as well wins over the pin.

### What comes back

The service sends numbers as strings so they stay exact. An answer reads them back:

| The service sends | You get |
| --- | --- |
| `"55830"`, `"0.8"`, `"-12.5"` | `BigDecimal` |
| `"2026-07-01"` | `Date` |
| `"2026-11-02T16:00:00+11:00"`, `"2026-11-02T05:00:00Z"` | `Time`, keeping its offset |
| any other string, number, `true`, `false`, `null` | as sent |
| an object | a hash with symbol keys, its values read the same way |

A text output that happens to look like a number (an id of `"1042"`) is read as a number too.

### What goes out

Facts go out exactly as you hold them: a `BigDecimal` is written as a JSON number in full, never rounded
through a `Float` or quoted as a string, and a `Date` or `Time` as an ISO 8601 string. Use `BigDecimal` for
money and rates; a `Float` goes out as Ruby writes it.

## Explain

```ruby
explained = ReasonMeThis.explain("sales_commission", facts, calculation: :year)

explained.outputs      # an answer, as run gives
explained.steps        # each step with its value, in the order they ran
explained.events       # what the answer set off: [Event(name: :quota_hit, data: {over_by: BigDecimal("1200")})]
```

A blueprint names its events beside its outputs (see the engine's Events guide). Only a traced run lists
them; a plain `run` answers the outputs alone.

## Manage definitions

```ruby
ReasonMeThis.push("bill", yaml: File.read("bill.yml"), cases: File.read("cases.yml"))
# => {problems: [], passed: 4, failed: 0, cases: [...]}

ReasonMeThis.publish("bill")        # => {version: 4, effective_from: Date(2026-11-08), live_version: 4}
ReasonMeThis.publish("bill", effective_from: Date.new(2027, 1, 1), live: false)
# => {version: 5, effective_from: Date(2027-01-01), live_version: 4}
ReasonMeThis.definitions
# => [{name: "bill", published_version: 5, live_version: 4, live_pinned: true,
#      versions: [{number: 1, effective_from: Date(2026-07-01), retired: false, published_at: Time(...)}, ...], updated_at: Time(...)}]
ReasonMeThis.definition("bill")     # => {name: "bill", yaml: "...", cases: "...", published_version: 5, live_version: 4, ...}
```

`publish` takes `effective_from:`, the day the new version takes effect (today by default), and `live: false`
to leave the version that is live now live, so the new one waits until it is made live on the service.
It answers what the service does: the new version, the day it takes effect and the live version. It used
to answer the version number alone; read that as `publish("bill")[:version]`.

## Schema

```ruby
schema = ReasonMeThis.schema("bill", calculation: :invoice)   # also version: 3, "bill@3" or on: Date
schema["inputs"]    # a JSON Schema (draft 2020-12) of the facts: types, enum, default, required
schema["outputs"]   # a JSON Schema of the outputs, with the types the blueprint declares
schema["version"]   # the version it describes
```

The schemas come back as the service sent them, with string keys (`"$schema"`) and no values read as
numbers or dates, so they can go straight to a JSON Schema validator. They describe the JSON: a number fact
is a JSON number and a number output exact text, as the service sends it.

## Errors

Every error is a `ReasonMeThis::Error`, with a message in plain words.

| Error | When |
| --- | --- |
| `Unauthorized` | the service refused the API key (401) |
| `NotFound` | no such definition or version (404) |
| `Gone` | the version asked for is retired (410) |
| `InvalidFacts` | the facts have problems (422); `#problems` lists them |
| `InvalidRequest` | the service refused what was asked rather than the facts (422): a day that is not a date, both `version:` and `on:`, or a schema of a calculation it cannot give (the service marks these `refused: "request"`; an older one is read by its wording); the message is the service's |
| `StepFailed` | a step failed while running (422); the message says which |
| `Timeout` | the run took too long on the service (503) |
| `Unreachable` | the service could not be reached: refused, DNS, or timed out |
| `InvalidSignature` | `Webhook.verify` was given a delivery that is unsigned, signed with another secret, or too old |
| `Rejected` | `push` or `publish` was refused: problems in the definition or failing cases; `#report` has them |

```ruby
begin
  ReasonMeThis.run("bill", facts)
rescue ReasonMeThis::InvalidFacts => e
  e.problems   # => ["hours is missing"]
end
```

## In a model

`ReasonMeThis::Model` works in any class, ActiveRecord or not. Each `reasons` block is one recipe: how to
build the facts, and, for `!`, what to save and what to run after.

```ruby
class Round < ApplicationRecord
  include ReasonMeThis::Model

  belongs_to :golfer
  has_many :hole_scores

  reasons :result, with: "golf_whs_golfer" do
    facts { {record: golfer.rounds.scored.last(20).map(&:to_fact), holes: holes.map(&:to_fact), played: played_on} }

    saves differential: "gross_differential", daily_handicap: "card.daily_handicap"
    saves into: :hole_scores, from: "card.scored", by: :hole
    saves on: :golfer, handicap_index: "new_ga_handicap"
    after { |explained| golfer.handicap_changes.create!(to: explained.at("new_ga_handicap")) }
    on(:handicap_cut) { |event| HandicapMailer.cut(golfer, event.data).deliver_later }
    keeps_receipts
  end
end

round.result             # run and read; saves nothing, remembered on this round
round.result_explained   # the same, with every step
round.result!            # run with every step, then save, in one transaction, then handle its events
```

`facts` runs on the record and takes the method's arguments: `facts { |year| ... }` makes `rep.statement(2026)`.

### What `!` saves

| Declaration | Writes |
| --- | --- |
| `saves column: "path"` | the value at `path` into a column of this record |
| `saves on: :golfer, column: "path"` | into a column of an associated record, and saves it |
| `saves into: :hole_scores, from: "path", by: :hole` | each row of the list at `path` into the association, matched on `hole`, so a second run updates rather than duplicates. Columns the child has are filled from the row's fields of the same name; give `column: :field` pairs to choose |

### Picking values

Each `saves column: source` takes its value from a path, or from a lambda for anything a path cannot say:

| Source | Gives |
| --- | --- |
| `"total_paid"` | an output |
| `"card.daily_handicap"` | a step inside a chained calculation |
| `"by_quarter"` | a whole list, for a JSON column |
| `"by_quarter.payout"` | one field from every row, as a list |
| `->(explained) { explained.at("by_quarter").last[:payout] }` | anything worked out from the explanation, such as one row |

```ruby
reasons :statement, with: "sales_commission@3", calculation: :year do
  facts { |year| {...} }
  saves total_paid: "total_paid", quarters: "by_quarter", payouts: "by_quarter.payout"
  saves q4_payout: ->(explained) { explained.at("by_quarter").last[:payout] }
end
```

A decimal or integer column gets the exact number. A JSON column gets values written as the service
writes them (`"5000"`, `"0.8"`, `"2026-01-01"`), so nothing is lost to floats. `explained.at(path)` reads
the same paths, and an `after` hook can save anything else: `after { |explained| update!(...) }`.

Everything happens in one transaction with the record's own `save!`: a refusal from the service, an
invalid record or a hook that raises leaves nothing written.

### Hooks and events

A recipe has two kinds of hook, for two jobs:

| | `after { \|explained\| ... }` | `on(:name) { \|event, explained\| ... }` |
| --- | --- | --- |
| For | writing more data, all or nothing with the saves | acting on what the rules decided: mail, jobs, calls to other services |
| Runs | on every `!`, inside the transaction, after the saves | for each event the answer set off, once the transaction has committed |
| When it raises | nothing is written | the saves stand; the error reaches the caller |

`after` is where to save anything `saves` cannot say, such as a new row: `after { |explained| update!(...) }`.
Because it runs inside the transaction, a job enqueued or a mail sent there can go out for a run that then
rolls back. Put those in `on`, against an event the blueprint names, so the condition is tested by the
blueprint's cases and the action waits for the commit. When `!` runs inside a transaction of your own, `on`
waits for that one to commit too, and never runs if it rolls back (Rails 7.2 or later; before that it runs
as soon as `!` has saved).

To act for every reasoning, in tables or jobs of your own, add a hook to the configuration:

```ruby
ReasonMeThis.configure do |config|
  config.after_reasoning do |record, name, explained|          # inside the transaction
    CalculationLog.create!(subject: record, reasoning: name, version: explained.version, stableford: explained.at("stableford"))
  end

  config.on_event do |record, name, event|                     # once it has committed
    EventRelayJob.perform_later(record, name.to_s, event.name.to_s, event.data)
  end
end
```

`on` acts on runs your app makes through a model. For events from any run of a published version, wherever
it came from, subscribe on the service instead (see [Webhooks](#webhooks)).

### Receipts

`keeps_receipts` writes a `ReasonMeThis::Receipt` for every `!`: the reasoning, the blueprint and the
version that ran, the calculation, and the facts, outputs, steps and events as the service showed them, so a
result can be explained long after the rules change. Add the table once:

```sh
bin/rails generate reason_me_this:receipts
bin/rails db:migrate
```

```ruby
round.reason_me_this_receipts.last.version   # => "3"
round.reason_me_this_receipts.last.steps     # the whole working, as it was
```

## Webhooks

The service can act on events itself. In the app's **Subscriptions** page, subscribe to a blueprint's
events, then either post them to a webhook or run another blueprint on their data. Every run of a published
version through the API delivers, whoever made it. **Deliveries** lists each one and sends a failed one again.

A webhook gets a JSON POST, signed with a secret shown once when the subscription is made:

```json
{"id": "evt_6f1c...", "event": "quota_hit", "definition": "commission", "version": 3, "calculation": "year",
 "data": {"rep": "42", "over_by": "1200"}, "ran_at": "2026-11-06T10:30:00Z", "chain": ["commission@3"]}
```

`Webhook.verify` checks the `RMT-Signature` header and reads the body as an event, with exact values:

```ruby
class RmtWebhooksController < ActionController::API
  def create
    event = ReasonMeThis::Webhook.verify(request.raw_post, request.headers["RMT-Signature"], ENV["RMT_WEBHOOK_SECRET"])
    QuotaHitJob.perform_later(event.data) if event.name == :quota_hit
    head :no_content
  rescue ReasonMeThis::InvalidSignature
    head :unauthorized
  end
end
```

`Webhook.payload` gives the whole body (`id`, `definition`, `version`, `chain` and the rest) instead. A
delivery signed more than five minutes from now is refused, so a captured one cannot be replayed. Use `id` to
ignore a delivery you have already handled: one that got no 2xx is sent again, up to nine times over about a
day.

## More than one service

Build a client for each service and use it as you would the module:

```ruby
client = ReasonMeThis::Client.new(url: tenant.rmt_url, api_key: tenant.rmt_key)
client.run("sales_commission", facts, calculation: :year)
```

A model runs on `reason_me_this_client`, which is the configured client unless you say otherwise:

```ruby
class Rep < ApplicationRecord
  include ReasonMeThis::Model

  def reason_me_this_client = tenant.reason_me_this_client
end
```

## In tests

A client talks through a connection: anything with `request(method, path, body)` that answers
`[status, parsed_json]`. Give it a fake to run offline:

```ruby
class FakeConnection
  def initialize(body) = @body = body
  def request(_method, _path, _body = nil) = [200, @body]
end

ReasonMeThis.configure { |config| config.connection = FakeConnection.new("total_paid" => "55830") }
```

## Against a local service

Run the service on port 3000, make an API key there, then:

```sh
export RMT_API_URL=http://localhost:3000/api
export RMT_API_KEY=your-key
bundle exec ruby -Ilib -r reason_me_this -e 'ReasonMeThis.configure { |c| c.url = ENV["RMT_API_URL"]; c.api_key = ENV["RMT_API_KEY"] }; p ReasonMeThis.definitions'
```

## Example

`examples/commissions` is a small Rails app that shows a sales rep's commission statement by quarter, worked
out by the service from the rep's deals. See its README.

## Development

```sh
bundle install
bundle exec rspec
bundle exec rubocop
```
