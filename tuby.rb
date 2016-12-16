require "socket"
require "http/parser"
require "stringio"

class Tuby
  def initialize(port, app)
    @server = TCPServer.new(port)
    @app = app
  end

  def start
    loop do
      socket = @server.accept
      connection = Connection.new(socket, @app)
      connection.process
    end
  end

  class Connection
    def initialize(socket, app)
      @socket = socket
      @app = app
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

      env = {}
      @parser.headers.each_pair do |name, value|
        # User-Agent => HTTP_USER_AGENT
        name = "HTTP_" + name.upcase.tr("-", "_")
        env[name] = value
      end
      env["PATH_INFO"] = @parser.request_path
      env["REQUEST_METHOD"] = @parser.http_method
      env["rack.input"] = StringIO.new

      send_response env
    end

    def send_response(env)
      status, headers, body = @app.call(env)

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

class App
  def call(env) # env => request info Hash
    sleep 5 if env["PATH_INFO"] == "/sleep"

    message = "Hello from the #{Process.pid}.\n"
    [
      200, # status code
      { 'Content-Type' => 'text/plain', 'Content-Length' => message.size.to_s }, # header
      [message] # body
    ]
  end
end

# a standard http request:
# GET /users HTTP/1.1
# Host: localhost
# Connection : close
#
# env = {
#   "REQUEST_METHOD"  => "GET",
#   "PATH_INFO"       => "/users",
#   "HTTP_VERSION"    => "1.1",
#   "HTTP_HOST"       => "localhost",
#   "HTTP_CONNECTION" => "close"
# }

# a standard rack response:
# [
#   200,
#   {
#     "Content-Length" => "34",
#     "Content-Type"   => "text/html"
#   },
#   [
#     "<html>",
#     " <h1>kthxbaie</h1>",
#     "</html>"
#   ]
# ]
#
# HTTP/1.1 200 OK
# Content-Length: 34
# Content-Type: text/html
#
# <html>
#   <h1>kthxbaie</h1>
# </html>

app = App.new
server = Tuby.new(3005, app)
puts "Plugging Tuby into port 3005"
server.start
