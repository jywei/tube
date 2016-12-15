require "socket"

class Tuby
  def initialize(port)
    @server = TCPserver.new(port)
  end

  def start
    socket = @server.accept
  end
end
