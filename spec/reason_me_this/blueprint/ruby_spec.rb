require 'reason_me_this/blueprint/ruby'
require 'reason_me_this/blueprint/yaml'
require_relative '../../fixtures/typed/venue_hire'

RSpec.describe ReasonMeThis::Blueprint::Ruby do
  def read(yaml) = ReasonMeThis::Blueprint::Yaml.read(yaml)

  def built(ruby) = Module.new.module_eval(ruby)

  it 'writes a blueprint file as the Ruby that builds the same document' do
    yaml = File.read(File.expand_path('../../fixtures/blueprints/room_hire/blueprint.yml', __dir__))

    ruby = described_class.write(read(yaml), 'room_hire')

    expect(ruby).to eq(<<~RUBY)
      # typed: strict

      ROOM_HIRE = ReasonMeThis::Blueprint.define do
        calculation :hire do
          inputs do
            number :hours
            number :hourly, default: 60
            date :booked_on, optional: true
          end

          formula :cost, 'hours * hourly'
          formula :total, 'ROUND(cost, 2)'

          outputs :total
          output :booked_on, optional: true
          event :long_hire, 'hours > 8', data: [:total]
        end

        calculation :deposit do
          inputs do
            number :total
          end

          formula :due, 'ROUND(total / total * total * 0.2, 2)'

          outputs :due
        end
      end #: ReasonMeThis::Blueprint
    RUBY
    expect(built(ruby).to_h).to eq(read(yaml))
  end

  it 'writes every kind of step with its own method, and builds the same document from it' do
    ruby = described_class.write(VENUE_HIRE.to_h, 'venue_hire')

    expect(ruby).to include("rules :loyalty, pick: :highest, otherwise: 0 do\n      rule :club, 'members >= 50', value: 15",
                            "formula(:deposit, 'ROUND(total * 0.2, 2)').when('NOT(deposit_paid)', else: 0)",
                            'lookup :period, table: :periods, where: {}, value: :period, band: {by: :hour, below: :until}',
                            "number :overtime_loading, default: BigDecimal('1.5')",
                            "{members: '>= 10', day: ['sat', 'sun'], discount: 5},")
    expect(ruby).not_to match(/^\s+(step|input) /)
    expect(built(ruby).to_h).to eq(VENUE_HIRE.to_h)
  end

  it 'writes what no method says with step and input, and still builds the same document' do
    document = read(<<~YAML)
      imports: [rates]
      tables:
        rates:
          - {from: 2026-07-01, 'per hour': 61.5, on: yes, note: "it's late"}
      calculations:
        hire:
          inputs:
            fee: {type: money, label: Fee}
            day: {type: date, one_of: [mon]}
            hours: {type: number, optional: false}
          steps:
            - {name: banded, band: {by: hours, of: rates}}
            - {name: rate, lookup: {table: rates, where: {from: 5}}}
            - {name: tier, rules: {pick: first, rules: [{name: low, when: hours < 2, value: 1, note: short}]}}
            - {name: total, formula: hours * 61.5, when: hours > 0}
          outputs: [total]
    YAML

    ruby = described_class.write(document, '3 rooms')

    expect(ruby).to include('BLUEPRINT_3_ROOMS = ', "import 'rates'",
                            %({from: Date.new(2026, 7, 1), "per hour": BigDecimal('61.5'), on: true, note: "it's late"},),
                            "input :fee, :money, label: 'Fee'", "input :day, :date, one_of: ['mon']", 'input :hours, :number, optional: false',
                            "step :banded, :band, {by: 'hours', of: 'rates'}", "step :rate, :lookup, {table: 'rates', where: {from: 5}}",
                            "step :tier, :rules, {pick: 'first', rules: [{name: 'low', when: 'hours < 2', value: 1, note: 'short'}]}",
                            "formula(:total, 'hours * 61.5').when('hours > 0')")
    expect(built(ruby).to_h).to eq(document)
  end

  it 'says what cannot be written in Ruby' do
    expect { described_class.write(read('calculations: {hire: {steps: [{name: total, formula: 1, note: x}], outputs: [total]}}'), 'hire') }.
      to raise_error(described_class::Unwritable, 'step total has formula, note; a step has one step type')
    expect { described_class.write(read("version: 2\ncalculations: {}"), 'hire') }.
      to raise_error(described_class::Unwritable, 'a blueprint has version, which cannot be written in Ruby; it takes imports, tables, calculations')
  end
end
