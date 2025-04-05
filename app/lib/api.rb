class Api
  class << self
    def instrument(key)
      StatsD.increment("api.#{self.name.downcase}.#{key}")
      StatsD.measure("api.#{self.name.downcase}.#{key}") do
        yield
      end
    end
  end
end
