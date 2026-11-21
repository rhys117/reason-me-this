# reason_me_this

The Ruby client for [Reason Me This](https://reason-me-this.com). It runs, explains, pushes and publishes definitions over HTTP
and keeps every number exact on the way out and on the way back.

It speaks HTTP and needs nothing beyond Ruby's standard library. With a licensed engine installed it can
instead run blueprints in your own process, with no service: see [Without the service](#without-the-service).

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
rmt ruby bill.yml                            # write bill.rb, the same blueprint in Ruby
rmt pull bill --ruby                         # bill/blueprint.rb in place of blueprint.yml
rmt check bill.rb && rmt push bill bill.rb   # a .rb file is run and sent as the YAML it builds
rmt test bill.rb                             # with the examples it gives as its cases
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

## Blueprints in Ruby

A blueprint can be written in Ruby instead of YAML. `ReasonMeThis::Blueprint.define` builds the same
document a blueprint file holds, so it is pushed, checked and run exactly as one is.

```ruby
ROOM_HIRE = ReasonMeThis::Blueprint.define do
  table :rates, [{period: "daytime", hourly: 60}, {period: "evening", hourly: 80}]

  calculation :hire do
    inputs do
      number :hours
      string :period, default: "daytime", one_of: {table: :rates, column: :period}
      boolean :member, default: false
      list :extras, default: [] do
        string :item
        number :price
      end
    end

    lookup :hourly, table: :rates, where: {period: :period}, value: :hourly
    formula :cost, "hours * hourly + SUM(PLUCK(extras, price))"
    rules :discount, pick: :highest, otherwise: 0 do
      rule :member, "member", value: 10
      rule :long_hire, "hours >= 8", value: 15
    end
    formula :total, "ROUND(cost * (100 - discount) / 100, 2)"
    formula(:deposit, "ROUND(total * 0.2, 2)").when("total > 200", else: 0)

    outputs :total, :discount
    output :deposit, type: :number
    event :long_hire, "hours >= 8", data: [:total]

    example "a member for two hours", facts: {hours: 2, member: true}, expect: {total: 108, discount: 10}
  end
end

ReasonMeThis.prove(ROOM_HIRE)                           # raises Rejected while it has problems or an example fails
ReasonMeThis.push("room_hire", yaml: ROOM_HIRE.yaml, cases: ROOM_HIRE.cases_yaml)    # to the service
File.write("config/blueprints/room_hire/blueprint.yml", ROOM_HIRE.yaml)    # or for a local engine
ROOM_HIRE.to_h                                          # the document, with text keys
```

- Names are symbols, and formulas and conditions are text, or a plain number or true or false.
- An input is written by its type: `number`, `string`, `date`, `time`, `boolean` or `list`, with `default:`,
  `optional:` and, on a number or a string, `one_of:`. A block on a `list` gives the fields of each row. `input :name,
  :type, key: value` writes an input of any other type or with any other key.
- A step is written by its type, name first: `formula`, `rules`, `lookup`, `decide`, `run`, `repeat`, `sum`,
  `group`, `compare` and `slice`, each taking the keys the blueprint format gives it. `step :name, :type, spec`
  writes a step of any other type.
- `.when(condition, else: formula)` on any step makes it conditional.
- `import "rates"` at the top imports a blueprint by name or path.
- `example "name", facts: {...}, expect: {...}` in a calculation is a worked example of it: the outputs those
  facts should give, any of them, and with `events:` the events they should set off. With `on: Date.new(...)`
  it runs on that day, so the blueprints it imports by name are the versions in force then; without it, the
  ones in force today. `cases` is every example as the list a cases file holds, and `cases_yaml` is that file. They are no part of `to_h` or `yaml`.
- `ReasonMeThis.prove(blueprint)` checks the blueprint and runs its examples without saving anything. It
  answers the report, or raises `ReasonMeThis::Rejected` with it when the blueprint has problems or an
  example fails, so a spec or a build step that calls it keeps an unproven blueprint out.
- The YAML is written with decimals exact (`BigDecimal("0.1")` stays `0.1`), dates as dates and no aliases.
  The first calculation is the default.
- The service or the engine still does the checking: a formula that cannot be read or a name that does not
  exist is a problem reported by `push`, or raised when a local engine runs it.

### From YAML, and with rmt

`rmt ruby bill.yml` writes `bill.rb` beside it, and `rmt pull bill --ruby` pulls a definition as
`bill/blueprint.rb`. The Ruby builds the same document the YAML holds, with a method for each input and
step; one that no method can say, such as a custom step, is written with `step` or `input`, so nothing is
lost. Comments in the YAML are not carried over. In Ruby it is
`ReasonMeThis::Blueprint::Ruby.write(ReasonMeThis::Blueprint::Yaml.read(yaml), "bill")`.

Wherever `rmt` takes a blueprint file it takes a `.rb` one: `check`, `test`, `run` and `push` run the file
and send the YAML of the `ReasonMeThis::Blueprint` it ends with. `rmt test bill.rb` and `rmt push bill bill.rb`
send the examples the file gives as its cases; a cases file named after it is sent in their place.

### With Sorbet

Every method carries an RBS comment signature and every block binds `self`, so a blueprint type checks in
a `# typed: strict` file with nothing added, once `tapioca gem reason_me_this` has written the gem's RBI
and Sorbet runs with `--parser=prism --enable-experimental-rbs-comments`. Annotate the constant:

```ruby
# typed: strict

ROOM_HIRE = ReasonMeThis::Blueprint.define do
  calculation :hire do
    inputs { nummber :hours }                 # Method `nummber` does not exist on `ReasonMeThis::Blueprint::Fields`
    lookup :hourly, table: "rates"            # Expected `Symbol` but found `String("rates")` for argument `table`
  end
end #: ReasonMeThis::Blueprint
```

Sorbet checks the shape: the methods, their keys and the kinds of value they take. It does not read a
formula or know which names exist; that stays with the service or the engine.

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
| `Rejected` | `push`, `publish` or `prove` was refused: problems in the definition or failing cases; `#report` has them |
| `EngineMissing` | a client was given an `engine` whose gems are not installed |
| `Unsupported` | a client with an `engine` was asked for something only the service does, such as `push` |

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

## Without the service

The engine that runs blueprints on the service is licensed separately. With it installed, a client runs
blueprint files in your own process: no URL, no key, and nothing sent anywhere.

```ruby
ReasonMeThis.configure do |config|
  config.engine = :rust                    # the engine on its native calculator
  config.blueprints = "config/blueprints"  # config/blueprints/hall_hire/blueprint.yml, as rmt pull writes it
  config.native_loop = false               # only to turn the engine's native loop off; leave it out otherwise
end

ReasonMeThis.run("hall_hire", {sessions: [{from: Time.iso8601("2026-11-02T16:00:00+11:00"), to: Time.iso8601("2026-11-02T22:00:00+11:00")}]})
```

`run`, `explain`, `schema`, `definitions` and `definition` answer as they do from the service, with the
same values and the same errors, so models, receipts and hooks work unchanged. A client of its own takes
the same options: `ReasonMeThis::Client.new(engine: :rust, blueprints: "config/blueprints")`.

An engine that can run a blueprint's steps natively does so unless `native_loop` is false, and falls back by
itself for a blueprint or a run it cannot. The answers are the same either way; the setting is there to rule
the native loop out. `ReasonMeThis.configuration.native_loop` reads `true` until you set it. To hear of what
the engine ran another way, or to have it refuse rather than fall back:

```ruby
ReasonMeThis.configure do |config|
  config.native_loop = :strict   # refuse a blueprint the native loop cannot run, with ReasonMeThis::Unsupported
  config.on_fallback { |taken| logger.warn(taken) }  # {kind: :fallback, blueprint: "rates", version: 2, reason: "..."}
end
```

The block is told once of each blueprint that falls back whole (`kind: :fallback`) and of each run that started
natively and was finished another way (`kind: :retreat`), which `:strict` reports and does not refuse. The
service, and an engine that has no native loop, take no notice of either setting.

- This gem does not depend on the engine. Add the engine gems you were given to your
  Gemfile. Without them, a client given an engine raises `ReasonMeThis::EngineMissing` when it is
  built, saying what could not be loaded. The configured client is built on its first use, so call
  `ReasonMeThis.default` in the initializer to find out at boot.
- A name is a folder in `blueprints`. A name the folder does not have is looked for among the blueprints
  the engine ships. Without `blueprints`, only the shipped ones run.
- A blueprint without versions is `NAME/blueprint.yml`, with `cases.yml` beside it if you keep one. It, and
  a shipped blueprint, refuse `version:` and a pinned name such as `"bill@3"` with `InvalidRequest` rather
  than ignore them, and an explanation's `version` is `"local"`. It takes `on:`, which chooses the versions
  of what it imports.
- A blueprint kept in versions has `NAME/versions.yml` beside a folder for each version: `NAME/v1/blueprint.yml`,
  `NAME/v2/blueprint.yml` and so on, each with its own `cases.yml` if you keep one. `versions.yml` lists every
  version, with the day it takes effect and a note if you like:

  ```yaml
  - version: 1
    note: As first written
  - version: 2
    effective_from: 2026-07-01
  ```

- `version: 2` or `"bill@2"` runs version 2. `on:` runs the version in force that day: the one with the
  latest `effective_from` on or before it, and of two that take effect the same day, the higher number. A
  version with no `effective_from` is in force before every dated one. Given neither, or `version: "latest"`,
  a run takes the version in force today. An explanation and a schema give the number of the version that ran.
- A version number `versions.yml` does not list, or `"draft"`, or a day before every version takes effect, is
  `NotFound`. Both `version:` and `on:` is `InvalidRequest`, as on the service. A `versions.yml` with problems
  refuses every run of its blueprint with `InvalidFacts`, listing them.
- `definitions` and `definition` list the versions as the service does. Every version listed counts as
  published and none is retired, so `published_version` is the highest number and `live_version` the one in
  force today. `definition` shows the blueprint and cases of the highest version.
- An `imports:` entry names a blueprint in the folder, or else one the engine ships. `rates@3` pins version 3.
  `rates` takes the version in force on the day the run is for, and through every import below it, or today
  when the run names no day. A blueprint run by `version:` alone imports as of today. An explanation's
  `imports` and a schema's `"imports"` give the version each blueprint imported by name ran at, through every
  import, such as `{rates: 1, tariff: "local"}`. A case in `cases.yml` with `on: 2026-06-30` runs on that day.
- `push` and `publish` raise `ReasonMeThis::Unsupported`: edit the files, and use the service to publish.
- A blueprint is read and checked on its first run and kept. It is read again when the day turns and, unless
  the engine is told the folder will not change (see the engine's own README), when a file in the folder is
  added, removed or changed.
- The engine is chosen for the whole process, not for each client, and a run has no time limit.
- A client takes a `url` or an `engine`, not both. The `rmt` CLI always uses the service.

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
SRB_SKIP_GEM_RBIS=1 bundle exec srb tc
```

The specs of a local engine are skipped unless the engine is in the bundle. To run them, write a
gemfile of your own that evaluates this one and adds the engine gems, such as `gemfiles/engine.gemfile`
(`gemfiles/` is ignored by git), and run `BUNDLE_GEMFILE=gemfiles/engine.gemfile bundle exec rspec`.
