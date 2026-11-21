require 'fileutils'
require 'open3'
require 'tmpdir'
require_relative '../fixtures/typed/room_hire'

RSpec.describe ReasonMeThis::Engines do
  let(:blueprints) { File.expand_path('../fixtures/blueprints', __dir__) }

  it 'loads no engine with the gem, which never needs one' do
    loaded, = Open3.capture2e(RbConfig.ruby, '-Ilib', '-e', 'require "reason_me_this"; print $LOADED_FEATURES.grep(%r{reason_me_this/engines/}).inspect')

    expect(loaded).to eq('[]')
  end

  it 'gives a client the connection an engine registered, built for the blueprints folder' do
    described_class.register(:abacus) { |blueprints:| FakeConnection.new(200, 'folder' => blueprints) }

    expect(ReasonMeThis::Client.new(engine: :abacus, blueprints: 'rules').run('bill', {}).folder).to eq('rules')
  end

  describe 'the native loop setting' do
    around do |example|
      forget
      example.run
      forget
    end

    def forget
      ReasonMeThis.configure do |config|
        config.to_h.each_key { |setting| config[setting] = nil }
        config.on_fallback
      end
    end

    def built(**settings)
      ReasonMeThis.configure do |config|
        config.engine = :abacus
        settings.each { |setting, value| config[setting] = value }
      end
      ReasonMeThis.run('bill', {}).to_h
    end

    it 'leaves an engine to its own default when the configuration says nothing' do
      described_class.register(:abacus) { |blueprints:, native_loop: true| FakeConnection.new(200, 'native' => native_loop, 'folder' => blueprints) }

      expect(built).to eq(native: true, folder: nil)
    end

    it 'reads as on until a host says otherwise, and as what the host said after' do
      read = [nil, false, :strict].map do |said|
        ReasonMeThis.configure { |config| config.native_loop = said }
        ReasonMeThis.configuration.native_loop
      end

      expect(read).to eq([true, false, :strict])
    end

    it 'hands an engine that takes one the block a host gives to be told what ran another way' do
      told = []
      described_class.register(:abacus) do |blueprints:, on_fallback: nil|
        on_fallback&.call({kind: :fallback, blueprint: 'bill', folder: blueprints})
        FakeConnection.new(200, {})
      end
      ReasonMeThis.configure { |config| config.on_fallback { |taken| told << taken } }

      built(native_loop: :strict)

      expect(told).to eq([{kind: :fallback, blueprint: 'bill', folder: nil}])
    end

    it 'reaches the engine when the configuration turns it off' do
      described_class.register(:abacus) { |blueprints:, native_loop: true| FakeConnection.new(200, 'native' => native_loop, 'folder' => blueprints) }

      expect(built(native_loop: false, blueprints: 'rules')).to eq(native: false, folder: 'rules')
    end

    it 'is not handed to an engine that has no native loop, which runs as it always did' do
      described_class.register(:abacus) { |blueprints:| FakeConnection.new(200, 'folder' => blueprints) }

      expect(built(native_loop: false, blueprints: 'rules')).to eq(folder: 'rules')
    end

    it 'is ignored by a client of the service' do
      ReasonMeThis.configure do |config|
        config.url = 'https://example.test/api'
        config.native_loop = false
      end

      expect(ReasonMeThis.default).to be_a(ReasonMeThis::Client)
    end
  end

  it 'refuses a name no engine could have, and a client given a service as well' do
    expect { ReasonMeThis::Client.new(engine: '../abacus') }.to raise_error(ReasonMeThis::Error, /\Aan engine is named in lowercase letters/)
    expect { ReasonMeThis::Client.new(url: 'https://example.test/api', engine: :rust) }.to raise_error(ReasonMeThis::Error, 'give a url or an engine, not both')
  end

  it 'says an engine is licensed separately when it is not installed' do
    expect { ReasonMeThis::Client.new(engine: :slide_rule, blueprints:) }.to raise_error(
      ReasonMeThis::EngineMissing, %r{\Athe slide_rule engine could not be loaded: cannot load such file -- reason_me_this/engines/slide_rule\. It is licensed}
    )
  end

  context 'with the engine installed', :engine do
    subject(:client) { ReasonMeThis::Client.new(engine: :rust, blueprints:) }

    it 'runs a blueprint from the folder and answers its outputs with exact numbers, as the service does' do
      answer = client.run('room_hire', {hours: BigDecimal('2.5'), hourly: 61, booked_on: Date.new(2026, 11, 2)})

      expect(answer.to_h).to eq(total: BigDecimal('152.5'), booked_on: Date.new(2026, 11, 2))
    end

    it 'answers the same with the native loop left on and turned off in the configuration' do
      answers = [nil, false].map do |native_loop|
        ReasonMeThis.configure do |config|
          config.engine = :rust
          config.blueprints = blueprints
          config.native_loop = native_loop
        end
        ReasonMeThis.run('room_hire', {hours: BigDecimal('2.5'), hourly: 61}).to_h
      end

      expect(answers).to eq([{total: BigDecimal('152.5'), booked_on: nil}] * 2)
    ensure
      ReasonMeThis.configure { |config| config.to_h.each_key { |setting| config[setting] = nil } }
    end

    it 'opens no connection to anything' do
      allow(Net::HTTP).to receive(:start).and_raise('a local engine reached for the network')
      allow(TCPSocket).to receive(:open).and_raise('a local engine reached for the network')

      expect(client.explain('room_hire', {hours: 2}).outputs.total).to eq(120)
      expect(client.definitions.size).to eq(3)
      expect(Net::HTTP).not_to have_received(:start)
    end

    it 'runs the calculation asked for, named by a symbol' do
      expect(client.run('room_hire', {total: 150}, calculation: :deposit).due).to eq(30)
    end

    it 'explains with the steps, the events set off and local for the version' do
      explained = client.explain('room_hire', {hours: 9})

      expect(explained.outputs.total).to eq(540)
      expect(explained.at('cost')).to eq(540)
      expect(explained.steps.map { |step| step[:step] }).to eq(%w[cost total])
      expect(explained.events).to eq([ReasonMeThis::Event.new(name: :long_hire, data: {total: 540})])
      expect(explained.version).to eq('local')
    end

    it 'refuses facts that do not fit, and a blueprint with problems, as the service does' do
      expect { client.run('room_hire', {hours: 'two', rooms: 1}) }.to raise_error(ReasonMeThis::InvalidFacts) do |refused|
        expect(refused.problems).to eq(['fact hours should be a number, not "two"',
                                        'fact rooms is not an input of hire; its inputs are hours, hourly, booked_on'])
      end
      expect { client.run('room_hire', [1]) }.to raise_error(ReasonMeThis::InvalidFacts, /facts should be an object of names and values/)
      expect { client.run('unsound', {hours: 2}) }.to raise_error(ReasonMeThis::InvalidFacts, /hire: step cost uses hourly, which is not an input/)
      expect { client.run('room_hire', {hours: 2}, calculation: :refund) }.to raise_error(ReasonMeThis::InvalidFacts, /no calculation refund/)
    end

    it 'fails as the service does when a step cannot be worked out' do
      expect { client.run('room_hire', {total: 0}, calculation: :deposit) }.to raise_error(ReasonMeThis::StepFailed, 'deposit > due: divides by zero')
    end

    it 'finds no definition for a name with no blueprint, and never reads a name as a path' do
      expect { client.run('ballroom', {}) }.to raise_error(ReasonMeThis::NotFound, 'no definition named ballroom')
      expect { client.run('Room.Hire', {hours: 1}) }.to raise_error(ReasonMeThis::NotFound)
      expect { client.explain('../blueprints/room_hire', {hours: 1}) }.to raise_error(ReasonMeThis::Unsupported)
    end

    it 'refuses a version for a blueprint kept without versions, and runs it for a day, which chooses the versions it imports' do
      [-> { client.run('room_hire@3', {hours: 1}) }, -> { client.run('room_hire', {hours: 1}, version: 'draft') }].each do |versioned|
        expect(&versioned).to raise_error(ReasonMeThis::InvalidRequest, 'room_hire runs from a blueprint file with no versions, so version does not apply')
      end
      expect(client.explain('room_hire', {hours: 1}, on: Date.new(2026, 7, 1))).to have_attributes(version: 'local')
    end

    it 'proves a blueprint written in Ruby by the examples it gives, as the service does' do
      expect(client.prove(ROOM_HIRE)).to include(problems: [], passed: 1, failed: 0)
    end

    it 'cannot push or publish, which belong to the service' do
      expect { client.push('room_hire', yaml: 'calculations: {}') }.to raise_error(
        ReasonMeThis::Unsupported, "a local engine cannot put /definitions/room_hire; it runs the blueprints in #{blueprints}"
      )
      expect { client.publish('room_hire') }.to raise_error(ReasonMeThis::Unsupported)
    end

    it 'imports by name from the folder first, then from the blueprints the engine ships' do
      expect(client.run('suite_hire', {hours: 2}).total).to eq(240)
    end

    it 'gives the JSON Schemas of a calculation, and refuses one the blueprint does not have' do
      schema = client.schema('room_hire', calculation: :deposit)

      expect(schema).to include('calculation' => 'deposit', 'version' => 'local')
      expect(schema['inputs']).to include('properties' => {'total' => {'type' => 'number'}}, 'required' => ['total'])
      expect { client.schema('room_hire', calculation: :refund) }.to raise_error(ReasonMeThis::InvalidRequest, /no calculation refund/)
      expect { client.schema('room_hire', version: 2) }.to raise_error(ReasonMeThis::InvalidRequest, /no versions/)
      expect { client.schema('ballroom') }.to raise_error(ReasonMeThis::NotFound)
    end

    it 'lists the blueprints in the folder as definitions with no versions' do
      expect(client.definitions.map { |definition| definition.except(:updated_at) }).to eq(
        %w[room_hire suite_hire unsound].map { |name| {name:, published_version: nil, live_version: nil, live_pinned: false, versions: []} }
      )
      expect(client.definitions.first[:updated_at]).to be_a(Time)
      expect(ReasonMeThis::Client.new(engine: :rust).definitions).to eq([])
    end

    it 'shows a definition with its blueprint and the cases beside it' do
      expect(client.definition('room_hire').keys).not_to include(:updated_at)
      expect(client.definition('room_hire')).to include(name: 'room_hire', yaml: start_with('# A room hired by the hour'),
                                                        cases: start_with('- name: two hours'), versions: [])
      expect(client.definition('suite_hire')).to include(cases: '')
      expect { client.definition('hall_hire') }.to raise_error(ReasonMeThis::NotFound, 'no definition named hall_hire')
    end

    it 'reasons for a model as the service does' do
      local = client
      booking = Class.new do
        include ReasonMeThis::Model

        define_method(:reason_me_this_client) { local }

        reasons :hire, with: 'room_hire' do
          facts { |hours| {hours:} }
        end
      end.new

      expect(booking.hire(3).total).to eq(180)
      expect(booking.hire_explained(3).at('cost')).to eq(180)
    end

    context 'with a folder that changes' do
      let(:blueprints) { Dir.mktmpdir }
      let(:suite) do
        <<~YAML
          imports: [room_hire]
          calculations: {suite: {inputs: {hours: {type: number}}, steps: [{name: room, run: {calculation: hire}}], outputs: [room]}}
        YAML
      end

      after { FileUtils.remove_entry(blueprints) }

      def write(name, yaml, at:)
        path = File.join(blueprints, name, 'blueprint.yml')
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, yaml)
        File.utime(at, at, path)
      end

      def hire(hourly) = "calculations: {hire: {inputs: {hours: {type: number}}, steps: [{name: total, formula: hours * #{hourly}}], outputs: [total]}}"

      it 'lists only the folders whose names a definition can have' do
        write('room_hire', hire(60), at: Time.at(1_000))
        write('Room-Hire copy', hire(60), at: Time.at(1_000))

        expect(client.definitions.map { |definition| definition[:name] }).to eq(['room_hire'])
      end

      it 'reads again when a blueprint is removed' do
        write('room_hire', hire(60), at: Time.at(1_000))
        write('annexe_hire', hire(40), at: Time.at(500))
        client.run('annexe_hire', {hours: 1})
        FileUtils.remove_entry(File.join(blueprints, 'annexe_hire'))

        expect { client.run('annexe_hire', {hours: 1}) }.to raise_error(ReasonMeThis::NotFound)
      end

      it 'keeps a blueprint it has read, and reads it again when it or one it imports changes' do
        write('room_hire', hire(60), at: Time.at(1_000))
        write('suite_hire', suite, at: Time.at(1_000))

        expect(client.run('suite_hire', {hours: 2}).room[:total]).to eq(120)

        write('room_hire', hire(70), at: Time.at(1_000))
        expect(client.run('suite_hire', {hours: 2}).room[:total]).to eq(120)

        write('room_hire', hire(80), at: Time.at(2_000))
        expect(client.run('suite_hire', {hours: 2}).room[:total]).to eq(160)
      end
    end

    context 'with a blueprint whose import is kept in versions' do
      let(:blueprints) { Dir.mktmpdir }
      let(:invoice) do
        ReasonMeThis::Blueprint.define do
          import :rates
          calculation :invoice do
            inputs { number :hours }
            run :billed, :hire
            outputs :billed
            example 'before July', on: Date.new(2026, 6, 30), facts: {hours: 1}, expect: {billed: {total: 50}}
            example 'from July', on: Date.new(2026, 7, 1), facts: {hours: 1}, expect: {billed: {total: 60}}
          end
        end
      end

      before do
        FileUtils.mkdir_p(File.join(blueprints, 'rates/v1'))
        FileUtils.mkdir_p(File.join(blueprints, 'rates/v2'))
        File.write(File.join(blueprints, 'rates/versions.yml'), "- {version: 1}\n- {version: 2, effective_from: 2026-07-01}\n")
        {1 => 50, 2 => 60}.each do |number, hourly|
          File.write(File.join(blueprints, "rates/v#{number}/blueprint.yml"),
                     "calculations: {hire: {inputs: {hours: {type: number}}, steps: [{name: total, formula: hours * #{hourly}}], outputs: [total]}}")
        end
      end

      after { FileUtils.remove_entry(blueprints) }

      it 'says which version of each import ran' do
        FileUtils.mkdir_p(File.join(blueprints, 'invoice'))
        File.write(File.join(blueprints, 'invoice/blueprint.yml'), invoice.yaml)

        explained = client.explain('invoice', {hours: 1}, on: Date.new(2026, 6, 30))

        expect(explained).to have_attributes(version: 'local', imports: {rates: 1})
        expect(client.schema('invoice', on: Date.new(2026, 7, 1))['imports']).to eq('rates' => 2)
      end

      it 'proves each example on the day it names, with the version of the import in force that day' do
        expect(client.prove(invoice)).to include(problems: [], passed: 2, failed: 0)
      end
    end

    it 'runs a blueprint the engine ships when the folder has none of that name' do
      sessions = [{from: Time.new(2026, 11, 2, 16, 0, 0, '+11:00'), to: Time.new(2026, 11, 2, 22, 0, 0, '+11:00')}]

      expect(client.run('hall_hire', {sessions:}).total).to eq(460)
      expect(ReasonMeThis::Client.new(engine: :rust).run('hall_hire', {sessions:}).total).to eq(460)
    end
  end
end
