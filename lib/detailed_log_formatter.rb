class DetailedLogFormatter < Logger::Formatter
  def call(severity, time, progname, msg)
    "[#{severity.upcase}] [#{time.strftime("%Y-%m-%d %H:%M:%S.%L")}]#{progname.present? ? " [#{progname}]" : ''} #{String === msg ? msg : msg.inspect}\n"
  end
end
