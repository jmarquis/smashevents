module Api
  module Retryable
    def with_retries(max_retries, batch_size: nil)
      api_name = self.name.downcase.demodulize
      retries = 0
      result = nil

      loop do
        result = if batch_size.present?
          yield batch_size
        else
          yield
        end

        break
      rescue Graphlient::Errors::GraphQLError => e
        raise e unless e.message.match?(/query complexity/)
        raise e unless batch_size.present?

        if retries >= max_retries
          Rails.logger.info "Retry threshold exceeded talking to #{api_name}, exiting: #{e.message}"
          raise e
        end

        retries += 1

        if batch_size.present?
          batch_size = (batch_size * 0.9).round == batch_size ? batch_size - 1 : (batch_size * 0.9).round
        end

        Rails.logger.info "Query complexity error talking to #{api_name}, reducing batch size and retrying. New batch size: #{batch_size}. Retry ##{retries}..."

        # No need to do backoff if we know the failure was due to query
        # complexity.
        sleep 1

        next
      rescue Graphlient::Errors::ExecutionError,
        Graphlient::Errors::FaradayServerError,
        Graphlient::Errors::ConnectionFailedError,
        Graphlient::Errors::TimeoutError,
        Faraday::ParsingError,
        Faraday::SSLError,
        Faraday::ServerError,
        OpenSSL::SSL::SSLError => e
        StatsD.increment("#{api_name}.request_error")

        if retries >= max_retries
          Rails.logger.info "Retry threshold exceeded talking to #{api_name}, exiting: #{e.message}"
          raise e
        end

        Rails.logger.info "Transient error communicating with #{api_name}, will retry: #{e.message}"

        sleep [(2 ** retries) + rand(-2..2), 1].max
        retries += 1

        next
      rescue StandardError => e
        Rails.logger.error "Unexpected error communicating with #{api_name}: #{e.message}"
        raise e
      end

      result
    end

  end
end
