class Api
  class << self
    def instrument(key)
      begin
        StatsD.increment("api.#{self.name.downcase}.#{key}")
        StatsD.measure("api.#{self.name.downcase}.#{key}") do
          yield
        end

        # We can assume it's a success if we get this far in this block.
        StatsD.increment("api_response.#{self.name.downcase}.#{key}.200")
      rescue Graphlient::Errors::Error => e
        status_code = e.try(:status_code)
        error_key = status_code.present? ? status_code.to_s : "#{e.class.name.demodulize.underscore}"
        StatsD.increment("api_response.#{self.name.downcase}.#{key}.#{error_key}")

        raise e
      end
    end
  end
end
