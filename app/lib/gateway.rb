class Gateway
  class << self

    def with_retries(max_retries, batch_size: nil)
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

        message = error_details(e)

        if retries >= max_retries
          Rails.logger.info "Retry threshold exceeded talking to #{api_name}, exiting: #{message}"
          raise e
        end

        Rails.logger.info "Transient error communicating with #{api_name}, will retry: #{message}"

        sleep [(2 ** retries) + rand(-2..2), 1].max
        retries += 1

        next
      rescue StandardError => e
        Rails.logger.error "Unexpected error communicating with #{api_name}: #{error_details(e)}"
        raise e
      end

      result
    end

    private

    def error_details(e)
      body = e.try(:response_body) || (e.response if e.is_a?(Graphlient::Errors::ServerError))

      [
        e.class.name,
        e.message,
        e.try(:response_status) || e.try(:status_code),
        body&.to_s&.truncate(1000),
        e.cause && "caused by #{e.cause.class}: #{e.cause.message}"
      ].compact_blank.join(' ||| ')
    end

    def instrument(key)
      StatsD.increment("api.#{api_name}.#{key}")
      result = StatsD.measure("api.#{api_name}.#{key}") do
        yield
      end

      # We can assume it's a success if we get this far in this block.
      StatsD.increment("api_response.#{api_name}.#{key}.200")

      result
    rescue Graphlient::Errors::Error => e
      status_code = e.try(:status_code)
      error_key = status_code.present? ? status_code.to_s : "#{e.class.name.demodulize.underscore}"
      StatsD.increment("api_response.#{api_name}.#{key}.#{error_key}")

      raise e
    rescue => e
      StatsD.increment("api_response.#{api_name}.#{key}.unknown_error")

      raise e
    end

    def api_name
      name.downcase.split('::').first
    end

  end
end
