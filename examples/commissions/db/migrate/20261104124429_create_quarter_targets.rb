class CreateQuarterTargets < ActiveRecord::Migration[8.1]
  def change
    create_table :quarter_targets do |t|
      t.references :rep, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.decimal :quota, precision: 14, scale: 2, null: false
      t.decimal :target_incentive, precision: 14, scale: 2, null: false
      t.decimal :draw, precision: 14, scale: 2
      t.timestamps
    end
  end
end
