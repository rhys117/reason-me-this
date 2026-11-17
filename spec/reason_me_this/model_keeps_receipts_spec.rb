require_relative '../support/records'
require_relative '../support/receipts'

RSpec.describe ReasonMeThis::Model, '#keeps_receipts' do
  include Records

  let(:round_class) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'rounds'
      def self.name = 'Round'

      include ReasonMeThis::Model

      reasons :result, with: 'golf_whs_golfer' do
        facts { {played: Date.new(2026, 4, 11)} }
        saves differential: 'gross_differential'
        keeps_receipts
      end
    end
  end
  let(:round) { round_class.create! }

  before do
    Receipts.create_table
    ActiveRecord::Base.connection.execute('DELETE FROM reason_me_this_receipts')
    traced = golf_trace(events: [{'name' => 'eagle', 'data' => {'hole' => '7'}}]).merge('version' => 3)
    ReasonMeThis.configure { |config| config.connection = FakeConnection.new(200, traced) }
  end

  after { ReasonMeThis.configure { |config| config.connection = nil } }

  it 'keeps a receipt of each saved reasoning: what ran, on what, and how it was worked out' do
    round.result!

    receipt = round.reason_me_this_receipts.sole
    expect(receipt).to have_attributes(reasoning: 'result', blueprint: 'golf_whs_golfer', version: '3', record_type: 'Round', record_id: round.id)
    expect(receipt.facts).to eq('played' => '2026-04-11')
    expect(receipt.outputs).to include('stableford' => '44')
    expect(receipt.steps.first).to include('step' => 'card')
    expect(receipt.events).to eq([{'name' => 'eagle', 'data' => {'hole' => '7'}}])
  end

  it 'keeps no receipt when the reasoning is refused' do
    ReasonMeThis.configure { |config| config.connection = FakeConnection.new(422, 'problems' => ['facts need holes']) }

    expect { round.result! }.to raise_error(ReasonMeThis::InvalidFacts)
    expect(ReasonMeThis::Receipt.count).to eq(0)
  end

  context 'with a local engine', :engine do
    let(:local) { ReasonMeThis::Client.new(engine: :rust, blueprints: File.expand_path('../fixtures/blueprints', __dir__)) }
    let(:hired_class) do
      local_client = local
      Class.new(ActiveRecord::Base) do
        self.table_name = 'rounds'
        def self.name = 'Round'

        include ReasonMeThis::Model

        define_method(:reason_me_this_client) { local_client }

        reasons :result, with: 'room_hire' do
          facts { {hours: 9} }
          saves differential: 'total'
          keeps_receipts
        end
      end
    end

    it 'saves values and keeps a receipt whose version is local' do
      hired = hired_class.create!
      hired.result!

      expect(hired.reload.differential).to eq(540)
      expect(hired.reason_me_this_receipts.sole).to have_attributes(blueprint: 'room_hire', version: 'local', outputs: {'total' => '540', 'booked_on' => nil},
                                                                    events: [{'name' => 'long_hire', 'data' => {'total' => '540'}}])
    end
  end
end
