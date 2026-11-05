require_relative '../support/records'

RSpec.describe ReasonMeThis::Model, '#saves values' do
  include Records

  let(:golfer_class) do
    Class.new(ActiveRecord::Base) do
      self.table_name = 'golfers'
      def self.name = 'Golfer'

      include ReasonMeThis::Model

      reasons :card, with: 'golf_whs_round' do
        saves holes: 'card.scored', points: 'card.scored.points'
        saves best_hole: -> (explained) { explained.at('card.scored').max_by { |hole| hole[:points] }[:hole] }
        after { |explained| update!(worst_points: explained.at('card.scored.points').min) }
      end
    end
  end
  let(:golfer) { golfer_class.create! }

  around do |example|
    ReasonMeThis.configure { |config| config.connection = FakeConnection.new(200, golf_trace(points: %w[2 3])) }
    example.run
  ensure
    ReasonMeThis.configure { |config| config.connection = nil }
  end

  it 'saves a list into a JSON column as the service writes its values' do
    golfer.card!

    expect(golfer.reload.holes).to eq([{'hole' => '1', 'points' => '2', 'adjusted' => '5'}, {'hole' => '2', 'points' => '3', 'adjusted' => '5'}])
  end

  it 'saves one field from every row of a list' do
    golfer.card!

    expect(golfer.reload.points).to eq(%w[2 3])
  end

  it 'saves what a lambda works out from the explanation, such as one row of a list' do
    golfer.card!

    expect(golfer.reload.best_hole).to eq(2)
  end

  it 'lets an after hook update the record it runs on' do
    golfer.card!

    expect(golfer.reload.worst_points).to eq(2)
  end
end
