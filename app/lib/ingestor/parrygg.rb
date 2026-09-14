module Ingestor
  class Parrygg < Base
    PROVIDER_NAME = 'parrygg'

    class << self
      def sync_streams
        Rails.logger.info 'Syncing streams'
        Tournament.not_past.reasonable_duration.where(provider: 'parrygg').each do |tournament|
          # TODO: Fetch tournament streams
        end
      end
    end
  end
end
