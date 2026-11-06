require 'openssl'

RSpec.describe ReasonMeThis::Webhook do
  let(:secret) { 'whsec_test' }
  let(:body) { '{"id":"evt_1","event":"quota_hit","definition":"commission","version":3,"data":{"over_by":"1200"},"chain":["commission@3"]}' }
  let(:now) { Time.at(1_793_962_902) }

  def signed(at: now.to_i, with: secret) = "t=#{at},v1=#{OpenSSL::HMAC.hexdigest('SHA256', with, "#{at}.#{body}")}"

  it 'reads a delivery signed with the secret, as an event with exact values' do
    delivered = described_class.verify(body, signed, secret, now:)

    expect(delivered).to eq(ReasonMeThis::Event.new(name: :quota_hit, data: {over_by: BigDecimal('1200')}))
    expect(described_class.payload(body, signed, secret, now:)).to include(definition: 'commission', version: 3, chain: ['commission@3'])
  end

  it 'refuses a delivery signed with another secret, signed too long ago, or not signed at all' do
    [signed(with: 'whsec_other'), signed(at: now.to_i - 301), nil, 't=1'].each do |signature|
      expect { described_class.verify(body, signature, secret, now:) }.to raise_error(ReasonMeThis::InvalidSignature)
    end
  end
end
