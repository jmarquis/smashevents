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

ActiveRecord::Schema[8.1].define(version: 2026_06_06_194449) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "discord_servers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "discord_server_id"
    t.string "note"
    t.integer "player_subscription_limit"
    t.datetime "updated_at", null: false
    t.index ["discord_server_id"], name: "index_discord_servers_on_discord_server_id", unique: true
  end

  create_table "entrants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.bigint "player2_id"
    t.bigint "player_id", null: false
    t.string "provider"
    t.string "provider_entrant_id"
    t.integer "rank"
    t.integer "seed"
    t.datetime "updated_at", null: false
    t.index ["event_id", "rank"], name: "index_entrants_on_event_id_and_rank"
    t.index ["event_id", "seed"], name: "index_entrants_on_event_id_and_seed"
    t.index ["event_id"], name: "index_entrants_on_event_id"
    t.index ["player2_id"], name: "index_entrants_on_player2_id"
    t.index ["player_id"], name: "index_entrants_on_player_id"
    t.index ["provider", "provider_entrant_id"], name: "index_entrants_on_provider_and_provider_entrant_id", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "entrants_synced_at"
    t.string "game_slug", null: false
    t.boolean "is_seeded"
    t.string "last_upset_tweet_id"
    t.integer "player_count"
    t.string "provider_event_id", null: false
    t.integer "ranked_player_count"
    t.datetime "sets_synced_at"
    t.boolean "should_display"
    t.string "slug"
    t.datetime "start_at"
    t.string "state"
    t.bigint "tournament_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "winner_entrant_id"
    t.index ["provider_event_id"], name: "index_events_on_provider_event_id", unique: true
    t.index ["tournament_id", "game_slug"], name: "index_events_on_tournament_id_and_game_slug", unique: true
    t.index ["tournament_id"], name: "index_events_on_tournament_id"
    t.index ["winner_entrant_id"], name: "index_events_on_winner_entrant_id"
  end

  create_table "games", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "display_threshold"
    t.string "hashtag"
    t.integer "ingestion_threshold"
    t.string "name"
    t.string "parrygg_id"
    t.string "rankings_regex"
    t.string "slug"
    t.integer "sort_order"
    t.integer "startgg_id"
    t.string "twitch_name"
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_games_on_slug"
    t.index ["startgg_id"], name: "index_games_on_startgg_id"
    t.index ["twitch_name"], name: "index_games_on_twitch_name"
  end

  create_table "notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "metadata"
    t.bigint "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.string "notification_type", null: false
    t.string "platform", null: false
    t.datetime "sent_at", null: false
    t.boolean "success", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
  end

  create_table "player_subscriptions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "discord_channel_id"
    t.string "discord_role_id"
    t.string "discord_server_id"
    t.string "discord_server_name"
    t.bigint "player_id", null: false
    t.datetime "updated_at", null: false
    t.index ["discord_server_id", "discord_channel_id"], name: "idx_on_discord_server_id_discord_channel_id_569c7cf4d2"
    t.index ["player_id"], name: "index_player_subscriptions_on_player_id"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "provider"
    t.string "provider_player_id"
    t.string "provider_user_id"
    t.string "provider_user_slug"
    t.string "tag"
    t.string "twitter_username"
    t.datetime "updated_at", null: false
    t.index ["provider", "provider_player_id"], name: "index_players_on_provider_and_provider_player_id", unique: true
    t.index ["provider", "provider_user_id"], name: "index_players_on_provider_and_provider_user_id", unique: true
    t.index ["provider_user_slug"], name: "index_players_on_provider_user_slug"
    t.index ["tag"], name: "gin_index_players_on_tag", opclass: :gin_trgm_ops, using: :gin
    t.index ["tag"], name: "index_players_on_tag"
  end

  create_table "tournament_overrides", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "include"
    t.string "provider"
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["include"], name: "index_tournament_overrides_on_include"
    t.index ["slug"], name: "index_tournament_overrides_on_slug", unique: true
  end

  create_table "tournaments", force: :cascade do |t|
    t.string "banner_image_url"
    t.string "city"
    t.string "country"
    t.datetime "created_at", null: false
    t.datetime "end_at"
    t.string "hashtag"
    t.string "name"
    t.string "profile_image_url"
    t.string "provider"
    t.string "provider_tournament_id"
    t.string "slug"
    t.datetime "start_at"
    t.string "state"
    t.json "stream_data"
    t.string "timezone"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tournaments_on_name"
    t.index ["provider", "provider_tournament_id"], name: "index_tournaments_on_provider_and_provider_tournament_id", unique: true
    t.index ["start_at"], name: "index_tournaments_on_start_at"
  end
end
