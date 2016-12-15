require "socket"

class Tuby
  def initialize(port)
    @server = TCPServer.new(port)
  end

  def start
    loop do
      socket = @server.accept
      connection = Connection.new(socket)
      connection.process
    end
  end

  class Connection
    def initialize(socket)
      @socket = socket
    end

    def process
      data = @socket.readpartial(1024)
      puts data
      send_response
    end

    def send_response
      @socket.write "HTTP/ 1.1 200 OK\r\n"
      @socket.write "\r\n"
      @socket.write "hello\n"

      close
    end

    def close
      @socket.close
    end
  end
end


server = Tuby.new(3005)
puts "Plugging Tuby into port 3005"
server.start
