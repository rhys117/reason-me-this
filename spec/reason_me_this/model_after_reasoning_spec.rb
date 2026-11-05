require_relative '../support/records'

RSpec.describe ReasonMeThis::Model, '#after_reasoning' do
  include Records

  let(:changes) { [] }
  let(:round_class) do
    seen = changes
    Class.new(ActiveRecord::Base) do
      self.table_name = 'rounds'
      def self.name = 'Round'

      include ReasonMeThis::Model

      reasons :result, with: 'golf_whs_golfer' do
        facts { {played: '2026-04-11'} }
        saves differential: 'gross_differential'
        after { |explained| seen << [id, explained.at('card.daily_handicap')] }
      end
    end
  end
  let(:round) { round_class.create! }

  around do |example|
    ReasonMeThis.configure { |config| config.connection = FakeConnection.new(200, golf_trace) }
    example.run
  ensure
    ReasonMeThis.configure do |config|
      config.connection = nil
      config.hooks.clear
    end
  end

  it 'runs on the record, with the explanation, after the saves' do
    round.result!

    expect(changes).to eq([[round.id, 23]])
  end

  it 'runs every hook the configuration names, for any record and reasoning, to store what the app wants' do
    stored = []
    ReasonMeThis.configure { |config| config.after_reasoning { |record, name, explained| stored << [record.class.name, name, explained.at('stableford')] } }

    round.result!

    expect(stored).to eq([['Round', :result, 44]])
  end

  it 'undoes the saves when a hook fails' do
    ReasonMeThis.configure { |config| config.after_reasoning { |*| raise 'the audit table is down' } }

    expect { round.result! }.to raise_error(RuntimeError, 'the audit table is down')
    expect(round.reload.differential).to be_nil
  end
end
