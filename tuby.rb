require "socket"

class Tuby
  def initialize(port)
    @server = TCPServer.new(port)
  end

  def start
    loop do
      socket = @server.accept

      data = socket.readpartial(1024)
      puts data

      socket.write "HTTP/ 1.1 200 OK\r\n"
      socket.write "\r\n"
      socket.write "hello\n"

      socket.close
    end
  end
end


server = Tuby.new(3005)
puts "Plugging Tuby into port 3005"
server.start
