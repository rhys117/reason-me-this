class CreateReasonMeThisReceipts < ActiveRecord::Migration[8.1]
  def change
    create_table :reason_me_this_receipts do |t|
      t.references :record, polymorphic: true, null: false
      t.string :reasoning, null: false
      t.string :blueprint, null: false
      t.string :version
      t.string :calculation
      t.json :facts, null: false
      t.json :outputs, null: false
      t.json :steps, null: false
      t.datetime :created_at, null: false
    end
  end
end
