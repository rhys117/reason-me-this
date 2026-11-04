class CreateDeals < ActiveRecord::Migration[8.1]
  def change
    create_table :deals do |t|
      t.references :rep, null: false, foreign_key: true
      t.string :code, null: false
      t.date :closed_on, null: false
      t.decimal :total_value, precision: 14, scale: 2, null: false
      t.integer :years, null: false, default: 1
      t.decimal :discount, precision: 5, scale: 4, null: false, default: 0
      t.string :kind, null: false
      t.decimal :share, precision: 5, scale: 4, null: false, default: 1
      t.date :cancelled_on
      t.timestamps
    end
  end
end
