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
    ReasonMeThis.configure { |config| config.connection = FakeConnection.new(200, golf_trace.merge('version' => 3)) }
  end

  after { ReasonMeThis.configure { |config| config.connection = nil } }

  it 'keeps a receipt of each saved reasoning: what ran, on what, and how it was worked out' do
    round.result!

    receipt = round.reason_me_this_receipts.sole
    expect(receipt).to have_attributes(reasoning: 'result', blueprint: 'golf_whs_golfer', version: '3', record_type: 'Round', record_id: round.id)
    expect(receipt.facts).to eq('played' => '2026-04-11')
    expect(receipt.outputs).to include('stableford' => '44')
    expect(receipt.steps.first).to include('step' => 'card')
  end

  it 'keeps no receipt when the reasoning is refused' do
    ReasonMeThis.configure { |config| config.connection = FakeConnection.new(422, 'problems' => ['facts need holes']) }

    expect { round.result! }.to raise_error(ReasonMeThis::InvalidFacts)
    expect(ReasonMeThis::Receipt.count).to eq(0)
  end
end
