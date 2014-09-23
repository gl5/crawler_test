#!/usr/bin/env ruby
# encoding: utf-8

require 'cgi'
require 'uri'
require './config'
require './models/keyword'
require './models/keyword_title'

class KeywordTitleCrawler

  def initialize(keyword, queue)
    @keyword = keyword
    @queue = queue
    # 与百度搜索建立socket连接
    @socket = TCPSocket.new(Configs.get('server.baidu.host'), Configs.get('server.baidu.port'))
  end

  def fetch
    response = ""
    # 重试次数
    retry_limit = Configs.get('app.retry_limit')
    p "Thread[#{Thread.current[:id]}] fetching title #{CGI::unescape(@keyword)} ..."
    begin
      response = ""
      retry_limit -= 1
      @socket.write("GET /s?wd=#{@keyword} HTTP/1.1\r\n")
      @socket.write("Host: www.baidu.com\r\n")
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
        p "Thread[#{Thread.current[:id]}] fetched keyword_title #{CGI::unescape(@keyword)} failed for #{e.message}"
        return
      end
    end

    response = response.force_encoding("UTF-8").chars.collect do |c|
      (c.valid_encoding?) ? c : '?'
    end.join

    # title与对应的domain 正则
    search_result_pattern = /<div class="[^"]*?c-container[^"]*?"[^>]*?id="\d{1,2}"[^>]*?>\s*?<h3 class="t\s*?"[^>]*?>\s*?<a[^>]*?href="(.*?)" target="_blank"[^>]*?>(.*?)<\/a>\s*?<\/h3>/

    # title 计数
    count = 0
    kw_id = Keyword.first(keyword: @keyword).id

    response.scan(search_result_pattern) do |match|
      break if count >= Configs.get('app.title_top')
      domain, title = *match
      # domain format
      domain = domain.gsub(/https:\/\//, "").gsub(/http:\/\//, "").gsub(/\/.*/, "")
      # title format
      title = title.gsub("<em>", "").gsub("</em>", "").gsub(" ", "")
      title = CGI::escape(title)
      # save to database
      KeywordTitle.insert(keyword_id: kw_id, title: title, domain: domain)
      count += 1
    end
  rescue => e
    p "Thread[#{Thread.current[:id]}] parsed title #{CGI::unescape(@keyword)} failed for #{e.message}"
  end
end
