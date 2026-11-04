# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_04_124429) do
  create_table "deals", force: :cascade do |t|
    t.integer "rep_id", null: false
    t.string "code", null: false
    t.date "closed_on", null: false
    t.decimal "total_value", precision: 14, scale: 2, null: false
    t.integer "years", default: 1, null: false
    t.decimal "discount", precision: 5, scale: 4, default: "0.0", null: false
    t.string "kind", null: false
    t.decimal "share", precision: 5, scale: 4, default: "1.0", null: false
    t.date "cancelled_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rep_id"], name: "index_deals_on_rep_id"
  end

  create_table "quarter_targets", force: :cascade do |t|
    t.integer "rep_id", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.decimal "quota", precision: 14, scale: 2, null: false
    t.decimal "target_incentive", precision: 14, scale: 2, null: false
    t.decimal "draw", precision: 14, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rep_id"], name: "index_quarter_targets_on_rep_id"
  end

  create_table "reps", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "deals", "reps"
  add_foreign_key "quarter_targets", "reps"
end
