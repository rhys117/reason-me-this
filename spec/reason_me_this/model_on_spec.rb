require_relative '../support/records'

RSpec.describe ReasonMeThis::Model, '#on' do
  include Records

  let(:seen) { [] }
  let(:round_class) do
    heard = seen
    Class.new(ActiveRecord::Base) do
      self.table_name = 'rounds'
      def self.name = 'Round'

      include ReasonMeThis::Model

      reasons :result, with: 'golf_whs_golfer' do
        facts { {played: '2026-04-11'} }
        saves differential: 'gross_differential'
        on(:handicap_cut) { |event| heard << [id, event.data[:new_ga_handicap], self.class.connection.transaction_open?] }
      end
    end
  end
  let(:round) { round_class.create! }
  let(:events) { [{'name' => 'handicap_cut', 'data' => {'new_ga_handicap' => '16.4'}}, {'name' => 'eagle', 'data' => {}}] }

  around do |example|
    ReasonMeThis.configure { |config| config.connection = FakeConnection.new(200, golf_trace(events:)) }
    example.run
  ensure
    ReasonMeThis.configure do |config|
      config.connection = nil
      config.hooks.clear
      config.event_handlers.clear
    end
  end

  it 'runs on the record for the event it names, once the saves are committed' do
    round.result!

    expect(seen).to eq([[round.id, BigDecimal('16.4'), false]])
  end

  it 'waits for a transaction the run is inside to commit, and never runs when it rolls back' do
    round_class.transaction do
      round.result!
      expect(seen).to eq([])
    end
    expect(seen.size).to eq(1)

    round_class.transaction do
      round.result!
      raise ActiveRecord::Rollback
    end
    expect(seen.size).to eq(1)
  end

  it 'does not run when the saves fail' do
    ReasonMeThis.configure { |config| config.after_reasoning { |*| raise 'the audit table is down' } }

    expect { round.result! }.to raise_error(RuntimeError)
    expect(seen).to eq([])
  end

  it 'runs every handler the configuration names, for every event' do
    heard = []
    ReasonMeThis.configure { |config| config.on_event { |record, name, event| heard << [record.class.name, name, event.name] } }

    round.result!

    expect(heard).to eq([['Round', :result, :handicap_cut], ['Round', :result, :eagle]])
  end
end
