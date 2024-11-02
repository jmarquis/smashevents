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

ActiveRecord::Schema[7.1].define(version: 2024_11_02_170738) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "entrants", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.bigint "event_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "startgg_entrant_id"
    t.integer "seed"
    t.integer "rank"
    t.index ["event_id", "rank"], name: "index_entrants_on_event_id_and_rank"
    t.index ["event_id", "seed"], name: "index_entrants_on_event_id_and_seed"
    t.index ["event_id"], name: "index_entrants_on_event_id"
    t.index ["player_id"], name: "index_entrants_on_player_id"
    t.index ["startgg_entrant_id"], name: "index_entrants_on_startgg_entrant_id", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.bigint "tournament_id", null: false
    t.integer "startgg_id", null: false
    t.string "game", null: false
    t.integer "player_count"
    t.string "featured_players", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ranked_player_count"
    t.datetime "notified_added_at"
    t.datetime "start_at"
    t.index ["startgg_id"], name: "index_events_on_startgg_id", unique: true
    t.index ["tournament_id", "game"], name: "index_events_on_tournament_id_and_game", unique: true
    t.index ["tournament_id"], name: "index_events_on_tournament_id"
  end

  create_table "players", force: :cascade do |t|
    t.integer "startgg_player_id"
    t.integer "startgg_user_id"
    t.string "tag"
    t.string "twitter_username"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["startgg_player_id"], name: "index_players_on_startgg_player_id", unique: true
    t.index ["startgg_user_id"], name: "index_players_on_startgg_user_id", unique: true
    t.index ["tag"], name: "index_players_on_tag"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "stream_data"
    t.string "timezone"
    t.string "hashtag"
    t.string "banner_image_url"
    t.string "profile_image_url"
    t.index ["name"], name: "index_tournaments_on_name"
    t.index ["start_at"], name: "index_tournaments_on_start_at"
    t.index ["startgg_id"], name: "index_tournaments_on_startgg_id", unique: true
  end

end
