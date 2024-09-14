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

ActiveRecord::Schema[7.1].define(version: 2024_09_14_161614) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "events", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.integer "startgg_id", null: false
    t.string "game", null: false
    t.integer "player_count"
    t.string "featured_players", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["startgg_id"], name: "index_events_on_startgg_id", unique: true
    t.index ["tournament_id", "game"], name: "index_events_on_tournament_id_and_game", unique: true
    t.index ["tournament_id"], name: "index_events_on_tournament_id"
  end

  create_table "tournament_overrides", force: :cascade do |t|
    t.string "slug"
    t.boolean "include"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["include"], name: "index_tournament_overrides_on_include"
    t.index ["slug"], name: "index_tournament_overrides_on_slug", unique: true
  end

  create_table "tournaments", force: :cascade do |t|
    t.integer "startgg_id"
    t.string "slug"
    t.string "name"
    t.datetime "start_at"
    t.datetime "end_at"
    t.string "city"
    t.string "state"
    t.string "country"
    t.integer "melee_player_count"
    t.integer "ultimate_player_count"
    t.string "melee_featured_players", array: true
    t.string "ultimate_featured_players", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "stream_data"
    t.string "timezone"
    t.string "hashtag"
    t.string "banner_url"
    t.index ["name"], name: "index_tournaments_on_name"
    t.index ["start_at"], name: "index_tournaments_on_start_at"
    t.index ["startgg_id"], name: "index_tournaments_on_startgg_id", unique: true
  end

end
