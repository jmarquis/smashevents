module Parrygg
  class Ingestor < ::Ingestor
    PROVIDER_NAME = 'parrygg'

    class << self
      def sync_streams
        Rails.logger.info 'Syncing streams for parrygg tournaments'

        Tournament.not_past.reasonable_duration.where(provider: 'parrygg').each do |tournament|
          next unless tournament.should_display?

          result = Gateway.tournament_streams(tournament_id: tournament.provider_tournament_id)

          tournament.streams = if result.present? && result[:streams].present?
            result[:streams].map do |stream_data|
              stream = tournament.streams.find { |s| s.channel?(stream_data[:channel]) } || tournament.streams.new

              stream.provider_stream_id = stream_data[:id]
              stream.channel = stream_data[:channel]
              stream.platform = case stream_data[:platform]
              when 'STREAM_PLATFORM_TWITCH'
                Stream::PLATFORM_TWITCH
              when 'STREAM_PLATFORM_YOUTUBE'
                Stream::PLATFORM_YOUTUBE
              else
                stream_data[:platform]
              end

              stream
            end
          else
            []
          end

          tournament.save!
        end
      end
    end
  end
end
