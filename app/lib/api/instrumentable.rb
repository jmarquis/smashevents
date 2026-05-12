module Api
  module Instrumentable
    def instrument(key)
      begin
        class_name = self.name.downcase.demodulize
        StatsD.increment("api.#{class_name}.#{key}")
        result = StatsD.measure("api.#{class_name}.#{key}") do
          yield
        end

        # We can assume it's a success if we get this far in this block.
        StatsD.increment("api_response.#{class_name}.#{key}.200")

        result
      rescue Graphlient::Errors::Error => e
        status_code = e.try(:status_code)
        error_key = status_code.present? ? status_code.to_s : "#{e.class.name.demodulize.underscore}"
        StatsD.increment("api_response.#{class_name}.#{key}.#{error_key}")

        raise e
      rescue => e
        StatsD.increment("api_response.#{class_name}.#{key}.unknown_error")

        raise e
      end
    end
  end
end
