require_relative '../support/records'

RSpec.describe ReasonMeThis::Model, '.saves' do
  include Records

  let(:connection) { FakeConnection.new(200, golf_trace) }
  let(:round_class) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'rounds'
      def self.name = 'Round'

      include ReasonMeThis::Model

      reasons(:result, with: 'golf_whs_golfer') { {played: '2026-04-11'} }
      saves :result, differential: 'gross_differential', stableford_points: 'stableford', daily_handicap: 'card.daily_handicap'
    end
  end
  let(:round) { round_class.create! }

  before { ReasonMeThis.configure { |config| config.connection = connection } }
  after { ReasonMeThis.configure { |config| config.connection = nil } }

  it 'runs with the trace and writes outputs and steps along the chain into the record' do
    round.result!

    expect(round.reload).to have_attributes(differential: BigDecimal('11.2'), stableford_points: 44, daily_handicap: 23)
    expect(connection.requests.last.last).to include(trace: true)
  end

  it 'writes nothing when the service refuses the facts' do
    connection = FakeConnection.new(422, 'problems' => ['facts need holes'])
    ReasonMeThis.configure { |config| config.connection = connection }

    expect { round.result! }.to raise_error(ReasonMeThis::InvalidFacts)
    expect(round.reload.differential).to be_nil
  end

  it 'leaves the plain reading as it was, saving nothing' do
    round.result

    expect(round.reload.differential).to be_nil
  end
end
