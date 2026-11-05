# reason_me_this

The Ruby client for [Reason Me This](https://reason-me-this.com). It runs, explains, pushes and publishes definitions over HTTP
and keeps every number exact on the way out and on the way back.

It only speaks HTTP: it needs nothing beyond Ruby's standard library and does not load the engine.

## Install

```ruby
gem "reason_me_this"
```

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
| `version:` | a published version number, `"latest"` (the default) or `"draft"` |
| `trace:` | `true` answers as `explain` does |

`"sales_commission@3"` pins the name to published version 3. A `version:` given as well wins over the pin.

### What comes back

The service sends numbers as strings so they stay exact. An answer reads them back:

| The service sends | You get |
| --- | --- |
| `"55830"`, `"0.8"`, `"-12.5"` | `BigDecimal` |
| `"2026-07-01"` | `Date` |
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
```

## Manage definitions

```ruby
ReasonMeThis.push("bill", yaml: File.read("bill.yml"), cases: File.read("cases.yml"))
# => {problems: [], passed: 4, failed: 0, cases: [...]}

ReasonMeThis.publish("bill")        # => 4, the new version
ReasonMeThis.definitions            # => [{name: "bill", published_version: 4, updated_at: "..."}]
ReasonMeThis.definition("bill")     # => {name: "bill", yaml: "...", cases: "...", published_version: 4}
```

## Errors

Every error is a `ReasonMeThis::Error`, with a message in plain words.

| Error | When |
| --- | --- |
| `Unauthorized` | the service refused the API key (401) |
| `NotFound` | no such definition or version (404) |
| `InvalidFacts` | the facts have problems (422); `#problems` lists them |
| `StepFailed` | a step failed while running (422); the message says which |
| `Timeout` | the run took too long on the service (503) |
| `Unreachable` | the service could not be reached: refused, DNS, or timed out |
| `Rejected` | `push` or `publish` was refused: problems in the definition or failing cases; `#report` has them |

```ruby
begin
  ReasonMeThis.run("bill", facts)
rescue ReasonMeThis::InvalidFacts => e
  e.problems   # => ["hours is missing"]
end
```

## In a model

`ReasonMeThis::Model` works in any class, ActiveRecord or not.

```ruby
class Rep < ApplicationRecord
  include ReasonMeThis::Model

  reasons :statement, with: "sales_commission@3", calculation: :year do |year|
    {deals: deals.closed_in(year).map(&:to_fact), quarters: quarter_targets.in(year).map(&:to_fact)}
  end
end

rep.statement(2026)               # => an answer, remembered on this rep for these arguments
rep.statement(2026).total_paid
rep.statement_explained(2026)     # the same run, explained
```

The block runs on the instance, takes the method's arguments, and returns the facts.

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
