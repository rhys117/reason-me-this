RSpec.describe ReasonMeThis::Explanation do
  subject(:explained) { described_class.new(outputs: ReasonMeThis::Answer.new(outputs), steps: ReasonMeThis::Values.read(steps)) }

  let(:outputs) { {'new_ga_handicap' => '16.4'} }
  let(:steps) do
    [{'step' => 'card', 'value' => {'daily_handicap' => '23'},
      'steps' => [{'step' => 'daily_handicap', 'value' => '23', 'formula' => 'ROUND(handicap)'},
                  {'step' => 'scored', 'value' => [{'hole' => '1', 'points' => '2'}, {'hole' => '2', 'points' => '3'}],
                   'rows' => [[{'step' => 'points', 'value' => '2'}], [{'step' => 'points', 'value' => '3'}]]}]},
     {'step' => 'new_ga_handicap', 'value' => '16.4'}]
  end

  it 'reads an output by its name' do
    expect(explained.at('new_ga_handicap')).to eq(BigDecimal('16.4'))
  end

  it 'reads a step inside a chained calculation by its path' do
    expect(explained.at('card.daily_handicap')).to eq(23)
  end

  it 'reads the value of a step that ran over a list, as its rows' do
    expect(explained.at('card.scored')).to eq([{hole: 1, points: 2}, {hole: 2, points: 3}])
  end

  it 'reads a step within each row of a list, as a list' do
    expect(explained.at('card.scored.points')).to eq([2, 3])
  end

  it 'says which part of a path it cannot find' do
    expect { explained.at('card.nope') }.to raise_error(ReasonMeThis::Error, 'no step card.nope in the trace')
  end
end
