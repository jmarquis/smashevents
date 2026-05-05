module Ingestor
  class Startgg < Base
    PROVIDER_NAME = 'startgg'

    class << self
      protected

      def tournaments(page:, cursor:, after_date:, updated_after:)
        Api::Startgg.with_retries(5, batch_size: 15) do |batch_size|
          Api::Startgg.tournaments(
            batch_size:,
            page:,
            after_date:,
            updated_after:
          )
        end
      end

      def tournament(slug:)
        Api::Startgg.with_retries(5) do
          Api::Startgg.tournament(slug:)
        end
      end
    end
  end
end
