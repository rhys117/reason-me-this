require 'open3'
require 'tmpdir'
require 'yaml'
require_relative '../fixtures/typed/room_hire'

RSpec.describe ReasonMeThis::Blueprint do
  let(:fixtures) { File.expand_path('../fixtures', __dir__) }

  def read(yaml) = YAML.safe_load(yaml, permitted_classes: [Date])

  it 'builds the document a blueprint file holds' do
    expect(ROOM_HIRE.to_h).to eq(read(File.read(File.join(fixtures, 'blueprints/room_hire/blueprint.yml'))))
    expect(read(ROOM_HIRE.yaml)).to eq(ROOM_HIRE.to_h)
  end

  it 'writes decimals exactly, dates as dates, and a value used twice in full both times' do
    row = {from: Date.new(2026, 7, 1), rate: BigDecimal('0.1000000000000000000001'), on: 'yes'}
    blueprint = described_class.define do
      table :rates, [row, row]
      calculation(:rate) { outputs :rates }
    end

    expect(blueprint.yaml).to eq(<<~YAML)
      tables:
        rates:
        - from: 2026-07-01
          rate: 0.1000000000000000000001
          'on': 'yes'
        - from: 2026-07-01
          rate: 0.1000000000000000000001
          'on': 'yes'
      calculations:
        rate:
          outputs:
          - rates
    YAML
  end

  it 'type checks in a strict file, as does a blueprint written with it' do
    checked, status = Open3.capture2e({'SRB_SKIP_GEM_RBIS' => '1'}, 'bundle', 'exec', 'srb', 'tc', chdir: File.expand_path('../..', __dir__))

    expect([checked.strip, status.success?]).to eq(['No errors! Great job.', true])
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
