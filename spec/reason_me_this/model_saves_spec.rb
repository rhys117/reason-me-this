require_relative '../support/records'

RSpec.describe ReasonMeThis::Model, '#saves' do
  include Records

  let(:connection) { FakeConnection.new(200, golf_trace) }
  let(:round_class) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'rounds'
      def self.name = 'Round'

      include ReasonMeThis::Model

      belongs_to :golfer, optional: true
      has_many :hole_scores, foreign_key: :round_id, class_name: 'HoleScore'

      reasons :result, with: 'golf_whs_golfer' do
        facts { {played: '2026-04-11'} }
        saves differential: 'gross_differential', stableford_points: 'stableford', daily_handicap: 'card.daily_handicap'
        saves into: :hole_scores, from: 'card.scored', by: :hole
        saves on: :golfer, handicap_index: 'new_ga_handicap'
      end
    end
  end
  let(:golfer) { Golfer.create!(handicap_index: 18.4) }
  let(:round) { round_class.create!(golfer:) }

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

  it 'writes each row of a list into child records, matched by a key so a second run updates them' do
    round.result!
    round.result!

    expect(round.hole_scores.order(:hole).pluck(:hole, :points, :adjusted)).to eq([[1, 2, 5], [2, 3, 5]])
  end

  it 'writes an output onto an associated record' do
    round.result!

    expect(golfer.reload.handicap_index).to eq(BigDecimal('16.4'))
  end

  it 'writes nothing anywhere when any record it would write is invalid' do
    ReasonMeThis.configure { |config| config.connection = FakeConnection.new(200, golf_trace(points: %w[2 -1])) }

    expect { round.result! }.to raise_error(ActiveRecord::RecordInvalid)
    expect([round.reload.differential, golfer.reload.handicap_index, HoleScore.count]).to eq([nil, BigDecimal('18.4'), 0])
  end

  it 'keeps several reasonings on one record apart, each with its own saves' do
    round_class.class_eval do
      reasons :index, with: 'golf_whs_handicap_index' do
        facts { {record: []} }
        saves on: :golfer, handicap_index: 'handicap_index'
      end
    end
    ReasonMeThis.configure { |config| config.connection = FakeConnection.new(200, golf_trace.merge('outputs' => {'handicap_index' => '17.0'})) }

    round.index!

    expect([round.reload.differential, golfer.reload.handicap_index]).to eq([nil, BigDecimal('17.0')])
  end

  it 'passes its reasonings to a subclass, which can add its own' do
    competition = Class.new(round_class) { reasons(:extra, with: 'golf_whs_round') { facts { {} } } }

    expect(competition.reasoned.keys).to eq(%i[result extra])
    expect(round_class.reasoned.keys).to eq(%i[result])
  end
end
