require 'json'
require 'fileutils'
require 'optparse'
require 'reason_me_this'
require 'reason_me_this/cli/output'

module ReasonMeThis
  class CLI
    HOSTED = 'https://reason-me-this.com/api'.freeze
    KEYS = 'https://reason-me-this.com/app/api_keys'.freeze

    USAGE = <<~TEXT.freeze
      Usage: rmt COMMAND [arguments] [options]

      Build and prove a blueprint:
        guide                                   print the guide to building a blueprint
        describe                                list step types with examples and the functions formulas can call
        check BLUEPRINT                         list problems with a blueprint file
        test BLUEPRINT CASES                    run each case's facts and compare the expected outputs
        run BLUEPRINT [--facts FILE] [--calculation NAME] [--trace]
                                                run a blueprint file; facts come from FILE or standard input

      Publish and run definitions:
        push NAME BLUEPRINT [CASES]             save a definition's draft, checked and tested
        publish NAME [--effective-from DATE] [--no-live]
                                                publish the draft as the next version
        run NAME [--version N|draft|--on DATE] [...]
                                                run a definition, or a shipped blueprint, by name
        schema NAME [--version N|draft|--on DATE] [--calculation NAME]
                                                print JSON Schemas for a calculation's inputs and outputs
        list                                    list the definitions and their published versions
        pull NAME [--dir DIR]                   write DIR/NAME/blueprint.yml and cases.yml

      A BLUEPRINT ending in .yml or .yaml or containing a / is a file; anything else is a name.
      --on YYYY-MM-DD picks the version in effect that day. publish --effective-from makes the new version take
      effect on that day (today by default); --no-live keeps the version that is live now live, so the new one waits.
      Every command but guide and describe needs RMT_API_KEY (create one at #{KEYS}).
      RMT_API_URL defaults to #{HOSTED}.

      Options for any command:
        --json                                  answer in JSON (the default when output is not a terminal)
        --text                                  answer in text (the default at a terminal)

      Exit codes: 0 success, 1 a run failed or the service has no such definition or version (404, 410),
      2 the blueprint has problems, 3 a case failed, 64 usage, 69 the service could not be reached,
      77 the service refused the key
    TEXT

    WORKFLOW = <<~MARKDOWN.freeze
      # Building a blueprint

      A blueprint is a YAML file describing calculations as data. You can turn a source document (a rulebook
      chapter, a price list, a policy) into a blueprint, prove it against worked examples, and run it.

      ## Workflow

      1. Run `rmt describe` to see every step type with an example, and the functions formulas can call.
      2. Read the source and list the outputs it asks for and the facts they depend on.
      3. Write worked examples first, in a cases file, from figures in the source where it gives them. Work out
         others by hand and say so in the case name.
      4. Write the blueprint.
      5. Run `rmt check BLUEPRINT` until it prints no problems.
      6. Run `rmt test BLUEPRINT CASES` until every case passes. Change the blueprint, not the cases,
         unless a case was worked out wrongly.
      7. Run `rmt run BLUEPRINT --facts FACTS.json` for new facts. Add `--trace` to see how every step
         was reached when a value surprises you.
      8. `rmt push NAME BLUEPRINT CASES` saves it as the draft of the definition NAME, and `rmt publish NAME`
         makes the draft the next version, which applications call. A draft with problems or a failing case
         is refused. `--effective-from DATE` makes it take effect on that day, and `--no-live` keeps the live
         version live.
      9. `rmt run NAME --facts FACTS.json` runs the live version; `--version draft` tries the draft first, and
         `--on DATE` runs the version in effect that day. `rmt schema NAME` prints the JSON Schemas of its facts
         and outputs, for a validator.

      Every command prints JSON to standard output when it is not a terminal, which is how an agent runs it,
      and text at a terminal; `--json` or `--text` chooses either way. Exit codes: 0 success, 1 a run failed
      or the service has no such definition or version, 2 the blueprint has problems, 3 a case failed,
      64 usage, 69 the service could not be reached, 77 the service refused the key. A blueprint imports
      others by name (`imports: [rates]`, `rates@2`, `rates@draft`), never by path.

    MARKDOWN

    def self.call(argv, env: ENV, connection: nil, **io)
      key = env['RMT_API_KEY'].to_s
      connection ||= Connection.new(env['RMT_API_URL'].to_s.empty? ? HOSTED : env['RMT_API_URL'], key)
      new(out: io.fetch(:out, $stdout), err: io.fetch(:err, $stderr), input: io.fetch(:input, $stdin), connection:, keyed: !key.empty?).call(argv.dup)
    end

    def initialize(out:, err:, input:, connection:, keyed:)
      @out = out
      @err = err
      @input = input
      @connection = connection
      @keyed = keyed
    end

    def call(argv)
      @output = Output.for(@out, format(argv))
      command = argv.shift
      return help(argv.first) if command == 'help'
      return help(command) if argv.delete('--help')

      dispatch(command, argv)
    rescue OptionParser::ParseError, Errno::ENOENT => e
      @err.puts(e.message)
      usage
    end

    private

    def dispatch(command, argv)
      case command
      when 'guide', 'describe', 'list' then send(command)
      when 'check', 'test', 'run', 'schema', 'push', 'publish', 'pull' then argv.first ? send(command, argv) : usage
      else usage
      end
    end

    def format(argv)
      chosen = %w[--json --text].select { |flag| argv.delete(flag) }
      chosen.last&.delete_prefix('--')&.to_sym
    end

    def guide
      on_service(:get, '/describe', keyless: true) do |_status, answer|
        @out.print(WORKFLOW, answer['guide'])
        0
      end
    end

    def describe
      on_service(:get, '/describe', keyless: true) { |_status, answer| answered(:describe, answer.except('guide'), 0) }
    end

    def check(argv)
      on_service(:post, '/check', {yaml: File.read(argv.first)}) do |_status, answer|
        answered(:problems, answer.slice('problems'), answer['problems'].any? ? 2 : 0)
      end
    end

    def test(argv)
      return usage unless argv[1]

      on_service(:post, '/check', {yaml: File.read(argv[0]), cases: File.read(argv[1])}) { |_status, answer| answered(:report, answer, proven(answer)) }
    end

    def run(argv)
      options = {}
      OptionParser.new do |parser|
        parser.on('--facts FILE') { |file| options[:facts] = file }
        choosing(parser, options)
        parser.on('--trace') { options[:trace] = true }
      end.parse!(argv)
      facts = read_facts(options) or return 1
      body = {facts:, **options.slice(:calculation, :version, :on, :trace)}
      return ran(:post, "/definitions/#{argv.first}/run", body, options) unless path?(argv.first)

      ran(:post, '/try', {yaml: File.read(argv.first), **body.except(:version, :on)}, options)
    end

    def choosing(parser, options)
      parser.on('--calculation NAME') { |name| options[:calculation] = name }
      parser.on('--version VERSION') { |version| options[:version] = version }
      parser.on('--on DATE') { |day| options[:on] = day }
    end

    def ran(method, path, body, options)
      on_service(method, path, body) do |status, answer|
        if status == 200
          answered(options[:trace] ? :trace : :outputs, answer, 0)
        else
          answered(:refusal, answer, 1)
        end
      end
    end

    def read_facts(options)
      JSON.parse(options[:facts] ? File.read(options[:facts]) : @input.read, decimal_class: BigDecimal)
    rescue JSON::ParserError => e
      answered(:problems, {'problems' => ["The facts are not valid JSON: #{e.message}"]}, 1)
      nil
    end

    def schema(argv)
      options = {}
      OptionParser.new { |parser| choosing(parser, options) }.parse!(argv)
      query = options.empty? ? '' : "?#{URI.encode_www_form(options)}"
      on_service(:get, "/definitions/#{argv.first}/schema#{query}") do |status, answer|
        status == 200 ? print_schema(answer) : answered(:refusal, answer, 1)
      end
    end

    # A JSON Schema is JSON, so it prints as JSON at a terminal too.
    def print_schema(schema)
      @out.puts(JSON.pretty_generate(schema))
      0
    end

    def push(argv)
      name, blueprint, cases = argv
      return usage unless blueprint

      body = {yaml: File.read(blueprint), cases: cases ? File.read(cases) : ''}
      on_service(:put, "/definitions/#{name}", body) { |_status, answer| answered(:report, answer, proven(answer)) }
    end

    def publish(argv)
      options = {}
      OptionParser.new do |parser|
        parser.on('--effective-from DATE') { |day| options[:effective_from] = day }
        parser.on('--[no-]live') { |live| options[:live] = live }
      end.parse!(argv)
      on_service(:post, "/definitions/#{argv.first}/publish", (options unless options.empty?)) do |status, answer|
        status == 201 ? answered(:published, answer, 0, name: argv.first) : answered(:report, answer, proven(answer))
      end
    end

    def list
      on_service(:get, '/definitions') { |status, answer| status == 200 ? answered(:definitions, answer, 0) : answered(:refusal, answer, 1) }
    end

    def pull(argv)
      options = {dir: '.'}
      OptionParser.new { |parser| parser.on('--dir DIR') { |dir| options[:dir] = dir } }.parse!(argv)
      name = argv.first
      on_service(:get, "/definitions/#{name}") do |status, answer|
        next answered(:refusal, answer, 1) unless status == 200

        write_new({'blueprint.yml' => answer['yaml'], 'cases.yml' => answer['cases']}.transform_keys { |file| File.join(options[:dir], name, file) })
      end
    end

    def write_new(files)
      existing = files.keys.select { |path| File.exist?(path) }
      return answered(:problems, {'problems' => existing.map { |path| "#{path} already exists" }}, 1) if existing.any?

      files.each do |path, content|
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
      end
      answered(:created, {'created' => files.keys}, 0)
    end

    def on_service(method, path, body = nil, keyless: false)
      return answered(:problems, {'problems' => ["#{path} needs an API key: create one at #{KEYS} and set RMT_API_KEY"]}, 64) unless keyless || @keyed

      status, answer = @connection.request(method, path, body)
      return answered(:refusal, answer, 77) if [401, 403].include?(status)

      yield(status, answer)
    rescue Unreachable => e
      answered(:refusal, {'error' => e.message}, 69)
    end

    def proven(answer)
      return 1 unless answer.key?('problems')
      return 2 if answer['problems'].any?

      answer['failed'].to_i.positive? ? 3 : 0
    end

    def path?(argument) = argument.end_with?('.yml', '.yaml') || argument.include?('/')

    def answered(kind, answer, code, context = {})
      @output.show(kind, answer, **context)
      code
    end

    def help(_command)
      @out.puts(USAGE)
      0
    end

    def usage
      @err.puts(USAGE)
      64
    end
  end
end
