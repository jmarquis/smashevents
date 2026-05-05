module Ingestor
  class Parrygg < Base
    PROVIDER_NAME = 'parrygg'

    class << self
      protected

      def tournaments(page:, cursor:, after_date:, updated_after:)
        # TODO: with_retries
        result = Api::Parrygg.tournaments(
          batch_size: 20,
          cursor:,
          updated_after:
        )

        return result[:tournaments], result.dig(:paginationResponse, :nextCursor, :id)
      end

      def tournament(slug:)
        # TODO: with_retries
        Api::Parrygg.tournament(slug:)
      end
    end
  end
end
