require 'socket'
require 'logging'
require 'uri'

# 设置日志
$log = Logging.logger(STDERR)
$log.level = :warn

class HttpProxy
  def initialize(s, p)
    headers = {}
    # 等待并获取客户端链接
    Socket.tcp_server_loop(s, p) do |connection|
      begin
        # while line = connection.gets.split(' ', 2) # Read lines from socket
        #   break if line[0] == ''
        #   if line[0][line[0].size - 1] == ':'
        #     headers[line[0].chop] = line[1].strip
        #   else
        #     headers[line[0]] = line[1].strip
        #   end
        # end
        # p headers
        p 'start'
        # while data = connection.read(1024) do
        #   i += 1
        #   p i
        #   puts data
        # end
         while line = connection.readline
           break if line ==  "\r\n"
           line = line.split(' ', 2)
           # 将协议头部保存为一个hash
           if line[0][line[0].size - 1] == ':'  # 去除‘:’号
             headers[line[0].chop] = line[1]
           else
             headers[line[0]] = line[1]
           end
         end

        first_head = headers.first  # 第一行
        TCPSocket.
        p headers.first

        # p request_line
        # verb = request_line[/^\w+/]
        # url     = request_line[/^\w+\s+(\S+)/, 1]
        # version = request_line[/HTTP\/(1\.\d)\s*$/, 1]
        # uri     = URI::parse url
        # p request_line, verb, url, version, uri
        # p "#{verb} #{uri.path}?#{uri.query} HTTP/#{version}\r\n"

        connection.close
        # data = connection.read(headers['Content-Length'].to_i)
        # p data
      rescue => e
        p e.message
        $log.warn 'connection error.........................'
        $log.warn e.message
      end


    end
  end
end

HttpProxy.new('0.0.0.0', 8088)