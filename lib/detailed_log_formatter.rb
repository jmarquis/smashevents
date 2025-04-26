class DetailedLogFormatter < Logger::Formatter
  @entrypoint = nil
  @uuid = nil

  def initialize
    super

    @uuid = SecureRandom.uuid_v4
  end

  def set_entrypoint(entrypoint)
    @entrypoint = entrypoint
  end

  def call(severity, time, progname, msg)
    "[#{severity.upcase}] [#{time.strftime("%Y-%m-%d %H:%M:%S.%L")}]#{progname.present? ? " [#{progname}]" : ''}#{@entrypoint.present? ? " [#{@entrypoint}]" : ''} [#{@uuid}] #{String === msg ? msg : msg.inspect}\n"
  end
end
