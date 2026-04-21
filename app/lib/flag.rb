class Flag
  class << self

    def radar?
      Rails.env.development?
    end

  end
end
