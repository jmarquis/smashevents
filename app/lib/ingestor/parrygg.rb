module Ingestor
  class Parrygg < Base
    PROVIDER_NAME = 'parrygg'

    class << self
      def sync_streams
        Rails.logger.info 'Syncing streams for parrygg tournaments'

        Tournament.not_past.reasonable_duration.where(provider: 'parrygg').each do |tournament|
          next unless tournament.should_display?

          stream_data = Api::Parrygg.tournament_streams(tournament_id: tournament.provider_tournament_id)

          tournament.stream_data = if stream_data.present? && stream_data[:streams].present?
            stream_data[:streams]&.map do |stream|
              stream_data = (tournament.stream_data || []).map(&:deep_symbolize_keys).find { |data| data[:name]&.downcase == stream[:channel].downcase } || {}

              stream_data[:name] = stream[:channel]
              stream_data[:source] = case stream[:platform]
              when 'STREAM_PLATFORM_TWITCH'
                Tournament::STREAM_SOURCE_TWITCH
              when 'STREAM_PLATFORM_YOUTUBE'
                Tournament::STREAM_SOURCE_YOUTUBE
              end

              stream_data
            end
          end

          tournament.save!
        end
      end
    end
  end
end
