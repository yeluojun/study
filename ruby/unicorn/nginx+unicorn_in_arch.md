# arch 下的 nginx + unicorn + rails app 的配置记录

## 一些简介 

### 什么是 is unicorn?

  为 Rack 应用程序设计的 HTTP server
  
### 什么是rack ?

1.Rack是Ruby应用与web服务器之间的一个接口，它在服务器与应用程序之间作为中间件，可以对用户的请求和程序的返回数据进行处理。
几乎所有主流的Ruby web框架都支持Rack接口

2.Rack的目标是提供一个最小的API连接到web servers和web框架 

### 什么是nginx
NGINX is a free, open-source, high-performance HTTP server and reverse proxy, as well as an IMAP/POP3 proxy server. 
(免费的高性能的http服务器，反向代理服务器，同时也是MAP/POP3 proxy server代理服务器。。。详情：https://www.nginx.com/resources/wiki/)


## 开始配置

### 1.配置unicorn

 
在Gemfile 添加：

```ruby
gem 'unicorn'
```

执行 bundle 命令 (bundle install or bundle)



#### 配置 config/unicorn.rb

```ruby
# Sample verbose configuration file for Unicorn (not Rack)
#
# This configuration file documents many features of Unicorn
# that may not be needed for some applications. See
# http://unicorn.bogomips.org/examples/unicorn.conf.minimal.rb
# for a much simpler configuration file.
#
# See http://unicorn.bogomips.org/Unicorn/Configurator.html for complete
# documentation.

app_path = File.expand_path(File.dirname(__FILE__) + '/../..') # 设置工程的根目录
shared_path = '/data/app/www/bus_api/shared' # 设置 shared 目录

# Use at least one worker per core if you're on a dedicated server,
# more will usually help for _short_ waits on databases/caches.
worker_processes  (ENV['RAILS_ENV'] == 'production' ? 4 : 1) # 设置worker数量， 跟cpu相关，一般等于cpu核数，根据访问量可以适度增减。

# Since Unicorn is never exposed to outside clients, it does not need to
# run on the standard HTTP port (80), there is no reason to start Unicorn
# as root unless it's from system init scripts.
# If running the master process as root and the workers as an unprivileged
# user, do this to switch euid/egid in the workers (also chowns logs):
# user "unprivileged_user", "unprivileged_group"

# Help ensure your application will always spawn in the symlinked
# "current" directory that Capistrano sets up.
working_directory app_path # available in 0.94.0+

# listen on both a Unix domain socket and a TCP port,
# we use a shorter backlog for quicker failover when busy
listen "#{shared_path}/tmp/pids/unicorn.sock", backlog: 64 # 监听  

# default listen is 8080  # 默认的端口是 8080
# listen 8088, tcp_nopush: true

# nuke workers after 30 seconds instead of 60 seconds (the default)
timeout 300  # 300秒没响应就杀掉请求。

# feel free to point this anywhere accessible on the filesystem
pid "#{shared_path}/tmp/pids/unicorn.pid" # 设置 pid 的路径

# By default, the Unicorn logger will write to stderr.
# Additionally, ome applications/frameworks log to stderr or stdout,
# so prevent them from going to /dev/null when daemonized here:
stderr_path app_path + '/log/unicorn.stderr.log' # 设置日志的目录
stdout_path app_path + '/log/unicorn.stdout.log'

# combine Ruby 2.0.0+ with "preload_app true" for memory savings
preload_app true

# Enable this flag to have unicorn test client connections by writing the
# beginning of the HTTP headers before calling the application.  This
# prevents calling the application for connections that have disconnected
# while queued.  This is only guaranteed to detect clients on the same
# host unicorn runs on, and unlikely to detect disconnects even on a
# fast LAN.
check_client_connection false  # 检测客户端链接

# local variable to guard against running a hook multiple times
run_once = true

before_fork do |server, worker|
  # the following is highly recomended for Rails + "preload_app true"
  # as there's no need for the master process to hold a connection
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!

  # Occasionally, it may be necessary to run non-idempotent code in the
  # master before forking.  Keep in mind the above disconnect! example
  # is idempotent and does not need a guard.
  if run_once
    # do_something_once_here ...
    run_once = false # prevent from firing again
  end

  # The following is only recommended for memory/DB-constrained
  # installations.  It is not needed if your system can house
  # twice as many worker_processes as you have configured.
  #
  # # This allows a new master process to incrementally
  # # phase out the old master process with SIGTTOU to avoid a
  # # thundering herd (especially in the "preload_app false" case)
  # # when doing a transparent upgrade.  The last worker spawned
  # # will then kill off the old master process with a SIGQUIT.
  # old_pid = "#{server.config[:pid]}.oldbin"
  # if old_pid != server.pid
  #   begin
  #     sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
  #     Process.kill(sig, File.read(old_pid).to_i)
  #   rescue Errno::ENOENT, Errno::ESRCH
  #   end
  # end
  #
  # Throttle the master from forking too quickly by sleeping.  Due
  # to the implementation of standard Unix signal handlers, this
  # helps (but does not completely) prevent identical, repeated signals
  # from being lost when the receiving process is busy.
  sleep 1
end

after_fork do |server, worker|
  # per-process listener ports for debugging/admin/migrations
  # addr = "127.0.0.1:#{9293 + worker.nr}"
  # server.listen(addr, :tries => -1, :delay => 5, :tcp_nopush => true)

  # the following is *required* for Rails + "preload_app true",
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection

  # if preload_app is true, then you may also want to check and
  # restart any other shared sockets/descriptors such as Memcached,
  # and Redis.  TokyoCabinet file handles are safe to reuse
  # between any number of forked children (assuming your kernel
  # correctly implements pread()/pwrite() system calls)
end

```


###2.配置nginx

####配置 /etc/nginx/nginx.conf

先分析一下nginx配置文件的结构:

nginx配置文件中主要包括六块： **main，events，http，server，location，upstream**


> main块：主要控制nginx子进程的所属用户/用户组、派生子进程数、错误日志位置/级别、pid位置、子进程优先级、进程对应cpu、进程能够打开的文件描述符数目等

> events块：控制nginx处理连接的方式

> http块：是nginx处理http请求的主要配置模块，大多数配置都在这里面进行
> 
> server块：是nginx中主机的配置块，可以配置多个虚拟主机
> 
> location块：是server中对应的目录级别的控制块，可以有多个
> 
> upstream块：是nginx做反向代理和负载均衡的配置块，可以有多个
     
     
````
# main
user  yeluojun users;  # 用户， 用户组

worker_processes  1;   # nginx 进程数，一般为cpu核心数或核心数的2倍

# pid         logs/nginx.pid; # 进程的文件位置
# error_log   logs/error.log; #全局错误日志的路径和日志等级

events {

    #use epoll;     #事件模型，use [ kqueue | rtsig | epoll | /dev/poll | select | poll ];
    worker_connections  1024;      #单个进程最大连接数 
}


http {

    include       mime.types;  #文件扩展名与文件类型映射表
    
    default_type  application/octet-stream;   #默认文件类型
    
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                     '"$http_user_agent" "$http_x_forwarded_for"';
                     
    access_log  logs/access.log main;     
                
    sendfile on; #开启高效文件传输模式。 普通应用on, 下载等需要IO高负荷的off, 图片显示不正常的off
    
    gzip  on;  # 启用gzip压缩输出
    
    gzip_disable "msie6";
    
    gzip_http_version 1.1;  # 压缩版本
    
    gzip_proxied any;
    
    gzip_min_length 500; # 最小压缩长度
    
    gzip_types  text/plain text/xml text/css
                text/comma-separated-values text/javascript
                application/x-javascript application/atom+xml;  # 压缩的类型
      

    # 设置服务器的地址，可作为负载均衡  
    upstream unicorn {
        server unix:/data/app/www/bus_api/shared/tmp/pids/unicorn.sock fail_timeout=0;
    }
    
    #server {      
    #
    #   }   
       
    }
    
    include servers-enabled/bus_api/*;    # 包含这么一个配置，配置的路径：/servers-enabled/bus_api/... 下面
}

````

创建 bus_api的配置：

```
mkdir -p servers-enabled/bus_api/ 

vim aervers-enabled/bus_api/bus_api.conf
```

配置 bus_api.conf:

```
server {
    listen 8089;  # 端口
  
    server_name 127.0.0.1;  # Replace this with your site's domain. 主机域名

    keepalive_timeout 300;  # 超时的时间

    client_max_body_size 4G;  # 请求体积，默认2m ,对当请求体积过大于设置的值时会报413 Request Entity Too Large的错误

    root /data/app/www/bus_api/current/public ;  # 主机站点的根目录

    #try_files $uri/index.html $uri.html $uri @unicorn;  # 判断文件是否存在，有则返回，没有返回最后一个参数
    
    # 对于一个请求，location的匹配规则。 先匹配普通location ，再匹配正则location
    location /{
          # 下面是反向代理的一些设置
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header Host $http_host;
          proxy_set_header X-Forwarded_Proto $scheme;
          proxy_redirect off; 
          proxy_pass http://unicorn;  # 对应 /etc/nginx/nginx.conf 
          proxy_read_timeout 300s;
          proxy_send_timeout 300s;
    }

    error_page 500 502 503 504 /500.html;
    location = /500.html {  
        root /home/yeluojun/rails_app/bus_api/current/public;
    }

    # 这里是通过nginx来访问 /assets/,不过这里不用通过这种方式访问。unicron会匹配路由
    #location ~* ^(/assets|/favicon.ico){
    #    access_log off;
    #    expires max;
    #}
}

```
   


配置 /etc/nginx/nginx.conf





