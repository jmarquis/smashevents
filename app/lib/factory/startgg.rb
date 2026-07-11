module Factory
  class Startgg < Base
    class << self

      def tournament(data)
        t = Tournament.find_by(provider: Provider::Startgg::PROVIDER_NAME, provider_tournament_id: data.id) || Tournament.new

        t.provider = Provider::Startgg::PROVIDER_NAME
        t.provider_tournament_id = data.id
        t.slug = data.slug.match(/^tournament\/(.*)/)[1]
        t.name = data.name
        t.hashtag = data.hashtag
        t.start_at = data.start_at.present? ? Time.at(data.start_at) : nil
        t.end_at = data.end_at.present? ? Time.at(data.end_at) : nil
        t.timezone = data.timezone
        t.city = data.city
        t.state = data.addr_state
        t.country = data.country_code

        if data.images.present?
          t.banner_image_url = data.images
            .filter { |image| image.type == 'banner' }
            .map { |image| image.url.gsub(/\?.*/, '') }
            .first

          t.profile_image_url = data.images
            .filter { |image| image.type == 'profile' }
            .map { |image| image.url.gsub(/\?.*/, '') }
            .first
        end

        t.stream_data = data.streams&.map do |stream|
          stream_data = (t.stream_data || []).map(&:deep_symbolize_keys).find { |data| data[:name]&.downcase == stream.stream_name.downcase } || {}

          stream_data[:name] = stream.stream_name
          stream_data[:source] = stream.stream_source

          stream_data
        end

        events = []

        return t, events unless data.events.present?

        data.events.each do |startgg_event|
          game = Game.find_by(startgg_id: startgg_event.videogame.id.to_i)
          next unless game.present?

          unless t.override&.include
            next unless startgg_event.num_entrants.present?
            next unless startgg_event.num_entrants >= game.ingestion_threshold
          end

          # Some TOs make a single tournament for a weekly for some reason, and
          # just move the tournament's start_at and end_at every week. So make
          # sure we don't consider old events part of the current tournament.
          # NB: Give a couple days of grace because some TOs also mess this up
          # for legitimate tournaments.
          next unless Time.at(startgg_event.start_at) >= t.start_at - 2.days

          event = t.events.find_by(provider_event_id: startgg_event.id) || t.events.new

          event.provider_event_id = startgg_event.id
          event.name = startgg_event.name
          event.slug = startgg_event.slug
          event.state = startgg_event.state
          event.start_at = Time.at(startgg_event.start_at)
          event.game = game
          event.entrant_count = startgg_event.num_entrants
          event.entrant_size = startgg_event.team_roster_size&.min_players || 1

          winner_data = startgg_event.standings&.nodes&.first&.entrant
          if event.state == Event::STATE_COMPLETED && winner_data.present?
            winner_entrant = event.entrants&.find_by(provider_entrant_id: winner_data.id)
            event.winner_entrant = winner_entrant if winner_entrant.present?
          else
            event.winner_entrant = nil
          end

          events << event
        end

        [t, events]
      end

      def entrant(data, event:)
        e = Entrant.find_by(provider: Provider::Startgg::PROVIDER_NAME, provider_entrant_id: data.id) || Entrant.new

        e.event = event
        e.provider = Provider::Startgg::PROVIDER_NAME
        e.provider_entrant_id = data.id
        e.seed = data.initial_seed_num

        rankings_key = event.game.rankings_key
        rankings_regex = event.game.rankings_regex
        e.rank = data.participants[0]&.player&.send(rankings_key)&.filter { |ranking| ranking.title&.match(rankings_regex) }&.first&.rank

        e.player = player(data.participants[0]&.player, tag: data.name)

        if data.participants.count > 1
          player2_rank = data.participants[1]&.player&.send(rankings_key)&.filter { |ranking| ranking.title&.match(rankings_regex) }&.first&.rank
          e.rank = player2_rank if player2_rank.present? && (e.rank.blank? || player2_rank < e.rank)

          e.player2 = if data.participants[1]&.player&.id == data.participants[0]&.player&.id
            e.player
          else
            player(data.participants[1]&.player)
          end
        end

        e
      end

      def player(data, tag: nil)
        return Player.new(provider: Provider::Startgg::PROVIDER_NAME, tag:) if data.blank?

        p = Player.find_by(provider: Provider::Startgg::PROVIDER_NAME, provider_player_id: data.id) || Player.new

        p.provider = Provider::Startgg::PROVIDER_NAME
        p.provider_player_id = data.id
        p.provider_user_id = data.user&.id
        p.provider_user_slug = data.user&.discriminator
        p.tag = data.gamer_tag
        p.twitter_username = data&.user&.authorizations&.first&.external_username
        p.name = data.user&.name

        p
      end

    end

  end
end
