require 'rails_helper'

RSpec.describe 'A rep statement' do
  it 'lists the reps' do
    rep
    get root_path

    expect(response.body).to include('Avery Quinn', rep_path(rep))
  end

  it "shows each quarter of the rep's year with the totals" do
    get rep_path(rep, year: 2026)

    expect(response.body).to include('Avery Quinn', '2026', 'Jan 1 to Mar 31', '$48,000', '80%', '$5,000', '$700', 'Oct 1 to Dec 31', '180%')
    expect(response.body).to include('Total paid', '$55,830')
  end

  context 'when the service cannot be reached' do
    let(:service) { ReasonMeThis::Connection.new('http://127.0.0.1:9', 'k') }

    it 'says so in plain words' do
      get rep_path(rep, year: 2026)

      expect(response.body).to include('could not reach the service')
    end
  end
end
