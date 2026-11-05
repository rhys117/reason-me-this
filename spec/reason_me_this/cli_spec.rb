require 'reason_me_this/cli'
require 'stringio'
require 'tmpdir'

RSpec.describe ReasonMeThis::CLI do
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:answers) { {} }
  let(:connection) { ScriptedConnection.new(answers) }
  let(:blueprint) { "calculations:\n  total:\n    inputs: {units: {type: number}}\n    steps: [{name: total, formula: units * 3}]\n    outputs: [total]\n" }

  def rmt(*argv, input: '', env: {'RMT_API_KEY' => 'k'}) = described_class.call(argv, out:, err:, input: StringIO.new(input), env:, connection:)

  def json = JSON.parse(out.string)

  def failing = [{'name' => 'two units', 'passed' => false, 'differences' => [{'output' => 'total', 'expected' => '6', 'actual' => '5'}]}]

  around { |example| Dir.mktmpdir { |dir| Dir.chdir(dir) { example.run } } }

  before do
    File.write('total.yml', blueprint)
    File.write('cases.yml', "- name: two units\n  facts: {units: 2}\n  expect: {total: 6}\n")
  end

  describe 'check' do
    it 'checks the file on the service and exits 0 when it has no problems' do
      answers[[:post, '/check']] = [200, {'problems' => [], 'passed' => 0, 'failed' => 0, 'cases' => []}]

      expect(rmt('check', 'total.yml')).to eq(0)
      expect(connection.requests).to eq([[:post, '/check', {yaml: blueprint}]])
      expect(json).to eq('problems' => [])
    end

    it 'exits 2 and lists the problems when there are some' do
      answers[[:post, '/check']] = [200, {'problems' => ['total: step total uses y'], 'passed' => 0, 'failed' => 0, 'cases' => []}]

      expect(rmt('check', 'total.yml')).to eq(2)
      expect(json['problems']).to eq(['total: step total uses y'])
    end
  end

  describe 'test' do
    it 'sends the blueprint and its cases and exits 3 when a case fails' do
      answers[[:post, '/check']] = [200, {'problems' => [], 'passed' => 0, 'failed' => 1,
                                          'cases' => failing}]

      expect(rmt('test', 'total.yml', 'cases.yml')).to eq(3)
      expect(connection.requests.first.last).to eq(yaml: blueprint, cases: File.read('cases.yml'))
    end

    it 'says which case failed and how, in text' do
      answers[[:post, '/check']] = [200, {'problems' => [], 'passed' => 1, 'failed' => 1,
                                          'cases' => failing}]

      rmt('test', 'total.yml', 'cases.yml', '--text')

      expect(out.string).to include('1 of 2 cases failed', 'two units', 'total: expected 6, got 5')
    end
  end

  describe 'run' do
    it 'runs a file on the service with facts from standard input' do
      answers[[:post, '/try']] = [200, {'total' => '6'}]

      expect(rmt('run', 'total.yml', input: '{"units": 2}')).to eq(0)
      expect(connection.requests).to eq([[:post, '/try', {yaml: blueprint, facts: {'units' => 2}}]])
      expect(json).to eq('total' => '6')
    end

    it 'runs a definition by name, a version and a calculation with the trace' do
      answers[[:post, '/definitions/bill/run']] = [200, {'outputs' => {'total' => '6'}, 'steps' => []}]
      File.write('facts.json', '{"units": 2.50}')

      expect(rmt('run', 'bill', '--facts', 'facts.json', '--version', 'draft', '--calculation', 'total', '--trace')).to eq(0)
      expect(connection.requests.last.last).to eq(facts: {'units' => BigDecimal('2.50')}, calculation: 'total', version: 'draft', trace: true)
    end

    it 'exits 1 with the problems when the facts do not fit' do
      answers[[:post, '/try']] = [422, {'problems' => ['facts need units']}]

      expect(rmt('run', 'total.yml', input: '{}')).to eq(1)
      expect(json).to eq('problems' => ['facts need units'])
    end
  end

  describe 'push, publish, list and pull' do
    it 'pushes a draft with its cases and exits 3 when the service says a case fails' do
      answers[[:put, '/definitions/total']] =
        [200, {'problems' => [], 'passed' => 0, 'failed' => 1, 'cases' => [{'name' => 'two units', 'passed' => false, 'error' => 'boom'}]}]

      expect(rmt('push', 'total', 'total.yml', 'cases.yml')).to eq(3)
      expect(connection.requests.last.last).to eq(yaml: blueprint, cases: File.read('cases.yml'))
    end

    it 'publishes the draft and says which version it made' do
      answers[[:post, '/definitions/total/publish']] = [201, {'version' => 4}]

      expect(rmt('publish', 'total', '--text')).to eq(0)
      expect(out.string).to include('Published total v4')
    end

    it 'lists the definitions' do
      answers[[:get, '/definitions']] = [200, {'definitions' => [{'name' => 'total', 'published_version' => 4, 'updated_at' => '2026-11-05T10:00:00Z'}]}]

      expect(rmt('list', '--text')).to eq(0)
      expect(out.string).to include('total', 'v4', '2026-11-05')
    end

    it 'pulls a definition into files and will not overwrite them' do
      answers[[:get, '/definitions/total']] = [200, {'yaml' => blueprint, 'cases' => ''}]

      expect(rmt('pull', 'total', '--dir', 'pulled')).to eq(0)
      expect(File.read('pulled/total/blueprint.yml')).to eq(blueprint)
      expect(rmt('pull', 'total', '--dir', 'pulled')).to eq(1)
    end
  end

  describe 'describe and guide' do
    def catalogue
      {'steps' => {'formula' => {'purpose' => 'work out a value', 'example' => '- name: x'}}, 'input_types' => {}, 'input_options' => {},
       'cases' => {}, 'formulas' => {'functions' => %w[ROUND IF], 'usage' => {}}, 'guide' => "## Shape\n"}
    end

    before { answers[[:get, '/describe']] = [200, catalogue] }

    it 'lists the step types and functions, without a key' do
      expect(rmt('describe', '--text', env: {})).to eq(0)
      expect(out.string).to include('formula', 'ROUND, IF', 'rmt guide')
    end

    it 'prints the workflow for rmt and then the service guide to writing a blueprint, without a key' do
      expect(rmt('guide', env: {})).to eq(0)
      expect(out.string).to include('Run `rmt check BLUEPRINT`', '## Shape')
      expect(out.string).not_to include('reckoning')
    end
  end

  describe 'exit codes' do
    it 'exits 64 and says where to get a key when a command needs one and none is set' do
      expect(rmt('check', 'total.yml', env: {})).to eq(64)
      expect(json['problems'].first).to include('RMT_API_KEY', 'https://reason-me-this.com/app/api_keys')
      expect(connection.requests).to be_empty
    end

    it 'exits 77 when the service refuses the key' do
      answers[[:get, '/definitions']] = [401, {'error' => 'unauthorized'}]

      expect(rmt('list')).to eq(77)
    end

    it 'exits 69 when the service cannot be reached' do
      unreachable = Object.new
      def unreachable.request(*) = raise(ReasonMeThis::Unreachable.new('could not reach the service'))

      expect(described_class.call(['list'], out:, err:, input: StringIO.new, env: {'RMT_API_KEY' => 'k'}, connection: unreachable)).to eq(69)
    end

    it 'exits 64 with the usage for an unknown command' do
      expect(rmt('frobnicate')).to eq(64)
      expect(err.string).to include('Usage: rmt COMMAND')
    end
  end
end
