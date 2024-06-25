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

ActiveRecord::Schema[7.1].define(version: 2024_06_24_161249) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "tournaments", force: :cascade do |t|
    t.integer "startgg_id"
    t.string "slug"
    t.string "name"
    t.date "start_at"
    t.date "end_at"
    t.string "games", array: true
    t.string "city"
    t.string "state"
    t.string "country"
    t.integer "player_count"
    t.string "featured_players"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["games"], name: "index_tournaments_on_games", using: :gin
    t.index ["name"], name: "index_tournaments_on_name"
    t.index ["start_at"], name: "index_tournaments_on_start_at"
    t.index ["startgg_id"], name: "index_tournaments_on_startgg_id", unique: true
  end

end
