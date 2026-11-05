require_relative '../../support/records'
require_relative '../../support/receipts'

RSpec.describe ReasonMeThis::Generators::ReceiptsGenerator do
  it 'writes a migration for a receipts table that points at any record' do
    expect(Receipts.migration).to include('create_table :reason_me_this_receipts', 't.references :record, polymorphic: true',
                                          't.json :facts', 't.json :steps', 't.string :version')
  end
end
