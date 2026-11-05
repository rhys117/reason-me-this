class CreateQuarterStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :quarter_statements do |t|
      t.references :rep, null: false, foreign_key: true
      t.date :start, null: false
      t.decimal :credited, precision: 14, scale: 2
      t.decimal :attainment, precision: 8, scale: 4
      t.decimal :commission, precision: 14, scale: 2
      t.decimal :spiffs, precision: 14, scale: 2
      t.decimal :earned, precision: 14, scale: 2
      t.decimal :payout, precision: 14, scale: 2
      t.decimal :balance_after, precision: 14, scale: 2
      t.timestamps
    end
    add_index :quarter_statements, %i[rep_id start], unique: true
  end
end
