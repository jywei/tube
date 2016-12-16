require "socket"
require "http/parser"

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
      @parser = Http::Parser.new(self)
    end

    def process
      until @socket.closed? || @socket.eof?
        data = @socket.readpartial(1024)
        @parser << data
      end
    end

    def on_message_complete
      puts "#{@parser.http_method} #{@parser.request_path}"
      puts " " + @parser.headers.inspect
      puts 

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
