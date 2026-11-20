require 'open3'
require 'tmpdir'
require 'yaml'
require_relative '../fixtures/typed/room_hire'
require_relative '../fixtures/typed/venue_hire'

RSpec.describe ReasonMeThis::Blueprint do
  let(:fixtures) { File.expand_path('../fixtures', __dir__) }

  def read(yaml) = YAML.safe_load(yaml, permitted_classes: [Date])

  it 'builds the document a blueprint file holds' do
    expect(ROOM_HIRE.to_h).to eq(read(File.read(File.join(fixtures, 'blueprints/room_hire/blueprint.yml'))))
    expect(read(ROOM_HIRE.yaml)).to eq(ROOM_HIRE.to_h)
  end

  it 'gives the examples of its calculations as the cases a cases file holds, and leaves them out of the document' do
    expect(ROOM_HIRE.cases).to eq(read(File.read(File.join(fixtures, 'blueprints/room_hire/cases.yml'))))
    expect(read(ROOM_HIRE.cases_yaml)).to eq(ROOM_HIRE.cases)
  end

  it 'names the calculation of an example that is not the first, and writes its facts as a blueprint writes values' do
    blueprint = described_class.define do
      calculation(:hire) { outputs :total }
      calculation :deposit do
        example 'a fifth down', facts: {total: BigDecimal('150.10'), on: Date.new(2026, 7, 1)}, expect: {due: BigDecimal('30.02')}, events: [:paid]
      end
    end

    expect(blueprint.cases_yaml).to eq(<<~YAML)
      - name: a fifth down
        facts:
          total: 150.1
          'on': 2026-07-01
        expect:
          due: 30.02
        events:
        - paid
        calculation: deposit
    YAML
    expect(described_class.define { calculation(:hire) { outputs :total } }.cases).to eq([])
  end

  it 'writes decimals exactly, dates as dates, times as ISO 8601 text, and a value used twice in full both times' do
    row = {from: Date.new(2026, 7, 1), opens: Time.new(2026, 7, 1, 9, 0, 0, '+10:00'), rate: BigDecimal('0.1000000000000000000001'), on: 'yes'}
    blueprint = described_class.define do
      table :rates, [row, row]
      calculation(:rate) { outputs :rates }
    end

    expect(blueprint.yaml).to eq(<<~YAML)
      tables:
        rates:
        - from: 2026-07-01
          opens: '2026-07-01T09:00:00+10:00'
          rate: 0.1000000000000000000001
          'on': 'yes'
        - from: 2026-07-01
          opens: '2026-07-01T09:00:00+10:00'
          rate: 0.1000000000000000000001
          'on': 'yes'
      calculations:
        rate:
          steps: []
          outputs:
          - rates
    YAML
  end

  it 'writes every kind of step, each with the keys it was given' do
    expect(VENUE_HIRE.to_h.dig('calculations', 'booking', 'steps')).to eq(read(<<~YAML))
      - {name: pieces, slice: {over: sessions, without: breaks, at_hours: [0, 7, 18, 21], after: {minutes: overtime_after, per: DATE(from), tag: overtime}}}
      - {name: priced, run: {calculation: piece, over: pieces, position: place}}
      - {name: minutes, sum: {output: minutes, of: priced}}
      - {name: cost, sum: {output: amount, of: priced}}
      - {name: by_period, group: {of: priced, by: [period], sum: [amount]}}
      - {name: discount, decide: {table: discounts, given: {members: members, day: day}, hit: first, value: discount, default: 0}}
      - name: loyalty
        rules:
          pick: highest
          otherwise: 0
          rules: [{name: club, when: members >= 50, value: 15}, {name: group, when: members >= 20, value: 12}]
      - {name: "off", compare: {steps: [discount, loyalty], pick: highest}}
      - {name: total, formula: 'ROUND(cost * (100 - off) / 100, 2)'}
      - {name: deposit, formula: 'ROUND(total * 0.2, 2)', when: NOT(deposit_paid), else: 0}
      - {name: instalments, repeat: {calculation: instalment, times: 3, with: {total: total}, position: number}}
      - {name: note, formula: 'CONCAT("Booked for ", minutes, " minutes")'}
    YAML
    expect(VENUE_HIRE.to_h.dig('calculations', 'piece', 'steps', 1)).to eq(
      'name' => 'period', 'lookup' => {'table' => 'periods', 'where' => {}, 'value' => 'period', 'band' => {'by' => 'hour', 'below' => 'until'}}
    )
  end

  it 'writes imports, list rows, the words an input takes and a repeat that runs until an output is true' do
    blueprint = described_class.define do
      import 'rates', 'shared/tables.yml'
      calculation :rounds do
        inputs do
          list(:blows) { number :damage }
          string :difficulty, one_of: %w[regular hard]
        end
        repeat :fight, :round, until: :over, limit: 50, carry: {standing: :standing_after}, start: {standing: 10}
        outputs :fight
      end
    end

    expect(blueprint.to_h).to eq(read(<<~YAML))
      imports: [rates, shared/tables.yml]
      calculations:
        rounds:
          inputs:
            blows: {type: list, of: {damage: {type: number}}}
            difficulty: {type: string, one_of: [regular, hard]}
          steps:
            - {name: fight, repeat: {calculation: round, until: over, limit: 50, carry: {standing: standing_after}, start: {standing: 10}}}
          outputs: [fight]
    YAML
  end

  it 'type checks in a strict file, as does a blueprint written with it' do
    checked, status = Open3.capture2e({'SRB_SKIP_GEM_RBIS' => '1'}, 'bundle', 'exec', 'srb', 'tc', chdir: File.expand_path('../..', __dir__))

    expect([checked.strip, status.success?]).to eq(['No errors! Great job.', true])
  end

  it 'is a blueprint the engine finds no problem with, whatever steps it has', :engine do
    Dir.mktmpdir do |blueprints|
      FileUtils.mkdir_p(File.join(blueprints, 'venue_hire'))
      File.write(File.join(blueprints, 'venue_hire/blueprint.yml'), VENUE_HIRE.yaml)
      client = ReasonMeThis::Client.new(engine: :rust, blueprints:)
      sessions = [{from: Time.new(2026, 11, 2, 16, 0, 0, '+11:00'), to: Time.new(2026, 11, 2, 22, 0, 0, '+11:00')}]

      answer = client.run('venue_hire', {sessions:, members: 25})

      expect(answer.to_h).to include(minutes: 360, off: 12, total: BigDecimal('404.8'), deposit: BigDecimal('80.96'))
      expect(answer.instalments).to eq([1, 2, 3].map { |number| {number:, due: BigDecimal('134.93')} })
      expect(client.run('venue_hire', {sessions:}).total).to eq(client.run('hall_hire', {sessions:}).total)
    end
  end

  it 'runs on a local engine as the blueprint file does', :engine do
    Dir.mktmpdir do |folder|
      FileUtils.mkdir_p(File.join(folder, 'room_hire'))
      File.write(File.join(folder, 'room_hire/blueprint.yml'), ROOM_HIRE.yaml)
      written, filed = [folder, File.join(fixtures, 'blueprints')].map { |blueprints| ReasonMeThis::Client.new(engine: :rust, blueprints:) }
      facts = {hours: BigDecimal('2.5'), hourly: 61}
      explained = [written, filed].map { |client| client.explain('room_hire', facts) }

      expect(explained.map { |explanation| [explanation.outputs.to_h, explanation.steps] }.uniq.size).to eq(1)
      expect(written.run('room_hire', {total: 150}, calculation: :deposit).due).to eq(30)
    end
  end
end
