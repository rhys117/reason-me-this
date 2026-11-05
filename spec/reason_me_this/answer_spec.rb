RSpec.describe ReasonMeThis::Answer do
  subject(:answer) do
    described_class.new('total_paid' => '55830', 'rate' => '-0.125', 'id' => 'D1',
                        'by_quarter' => [{'start' => '2026-01-01', 'payout' => '5000'}], 'version' => 3)
  end

  it 'reads numeric strings as exact decimals and ISO dates as dates, all the way down, with symbol keys' do
    expect(answer.to_h).to eq(total_paid: BigDecimal('55830'), rate: BigDecimal('-0.125'), id: 'D1',
                              by_quarter: [{start: Date.new(2026, 1, 1), payout: BigDecimal('5000')}], version: 3)
  end

  it 'keeps a string shaped like a date that is not one' do
    expect(described_class.new('code' => '2026-13-45')[:code]).to eq('2026-13-45')
  end

  it 'reads an output by method, symbol or string' do
    expect([answer.total_paid, answer[:total_paid], answer['total_paid']]).to all(eq(BigDecimal('55830')))
  end

  it 'answers NoMethodError for an output it does not have' do
    expect(answer).not_to respond_to(:missing)
    expect { answer.missing }.to raise_error(NoMethodError)
  end
end
