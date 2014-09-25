#!/usr/bin/env ruby
# encoding: utf-8

require 'cgi'
require './config'

class KeywordCrawler

  def initialize(keyword, buffer_queue)
    @keyword = keyword
    @buffer_queue = buffer_queue
    # 奇虎360搜索，与建立socket连接
    @socket = TCPSocket.new(Configs.get('server.qihu.host'), Configs.get('server.qihu.port'))
  end

  def fetch
    response = ""
    # 重试次数
    retry_limit = Configs.get('app.retry_limit')
    p "Thread[#{Thread.current[:id]}] fetching keyword #{CGI::unescape(@keyword)} ..."
    begin
      response = ""
      retry_limit -= 1
      @socket.write("GET /s?q=#{@keyword} HTTP/1.1\r\n")
      @socket.write("Host: www.so.com\r\n")
      @socket.write("Cache-Control: no-cache\r\n")
      @socket.write("Connection: keep-alive\r\n")
      @socket.write("\r\n")

      while line = @socket.gets
        response += line
      end
      # 获取 response 信息后关闭socket
      @socket.close
    rescue => e
      if retry_limit > 0
        sleep(5)
        retry
      else
        p "Thread[#{Thread.current[:id]}] fetched keyword #{CGI::unescape(@keyword)} failed for #{e.message}"
        return
      end
    end

    response = response.force_encoding("UTF-8")

    #关键词正则
    keyword_pattern = /<th><a href=\"\/s\?q=(.+?)&src=related\" data-type=/

    # 将抓取的结果放到buffer_queue中
    response.scan(keyword_pattern) do |match|
      kw = match.first
      next unless kw
      @buffer_queue << [:keyword, {keyword: kw}]
    end
  rescue => e
    p "Thread[#{Thread.current[:id]}] parsed keyword #{CGI::unescape(@keyword)} failed for #{e.message}"
  end
end
