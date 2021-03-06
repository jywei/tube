require "socket"
require "http/parser"
require "stringio"
require "thread"
require "eventmachine"

class Tuby
  def initialize(port, app)
    @server = TCPServer.new(port)
    @app = app
  end

  def prefork(workers)
    workers.times do
      fork do
        puts "Forked #{Process.pid}"
        start
      end
    end
    Process.waitall # wait all child processes to accept, then exercute (in case of zombie processes)
  end

  def start
    loop do
      socket = @server.accept
      Thread.new do # more memory consuming
        connection = Connection.new(socket, @app)
        connection.process
      end
    end
  end

  def start_em
    EM.run do
      EM.start_server "localhost", 3005, EMConnection do |connection|
        connection.app = @app
      end
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

    REASONS = {
      200 => "OK",
      404 => "Not Found"
    }

    def send_response(env)
      status, headers, body = @app.call(env)
      reason = REASONS[status]

      @socket.write "HTTP/1.1 #{status} #{reason}\r\n"
      headers.each_pair do |name, value|
        @socket.write "#{name}: #{value}\r\n"
      end
      @socket.write "\r\n"
      body.each do |chunk|
        @socket.write chunk
      end
      body.close if body.respond_to? :close

      close
    end

    def close
      @socket.close
    end
  end

  class EMConnection < EM::Connection
    attr_accessor :app

    def post_init
      @parser = Http::Parser.new(self)
    end

    def receive_data(data)
      @parser << data
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

    REASONS = {
      200 => "OK",
      404 => "Not Found"
    }

    def send_response(env)
      status, headers, body = @app.call(env)
      reason = REASONS[status]

      send_data "HTTP/1.1 #{status} #{reason}\r\n"
      headers.each_pair do |name, value|
        send_data "#{name}: #{value}\r\n"
      end
      send_data "\r\n"
      body.each do |chunk|
        send_data chunk
      end
      body.close if body.respond_to? :close

      close_connection_after_writing
    end
  end

  class Builder
    attr_reader :app

    def run(app)
      @app = app
    end

    def self.parse_file(file)
      content = File.read(file)
      builder = Builder.new
      builder.instance_eval(content)
      builder.app
    end
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

app = Tuby::Builder.parse_file("config.ru")

server = Tuby.new(3005, app)
puts "Plugging Tuby into port 3005"
# server.start
# server.prefork 3 #prefork threaded server
server.start_em
