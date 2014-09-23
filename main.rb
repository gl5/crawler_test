#!/usr/bin/env ruby
# encoding: utf-8

require 'thread'
require 'cgi'
require './crawlers/keyword_crawler'
require './crawlers/keyword_title_crawler'

# run it like this: ruby main.rb "中国" 10000 5

#ARGV
if ARGV == nil or ARGV.length < 1
  p "--- sample ---"
  p "run it like this: ruby main.rb '中国' "
  p "help: 中国-> initial keyword"
  exit(0)
end

Thread.current[:id] = 'MAIN'
$initial_keyword = ARGV[0] # 选择一个词，作为起点
$thread_num = Configs.get('app.threads') # 要开启的线程数量
$queue = Queue.new # 工作队列
$threads = [] # 线程数组
$sleeping_threads = 0
$mutex = Mutex.new #锁
$crawler_map = {keyword: KeywordCrawler, title: KeywordTitleCrawler} #爬行类型对应的爬行模块类

# 爬取第一个关键字
kw_crawler = KeywordCrawler.new(CGI::escape($initial_keyword), $queue)
kw_crawler.fetch

# 初始化线程
$thread_num.times do |thread_index|
  $threads << Thread.new do
    p "Thread[#{thread_index}] starting ..."
    Thread.current[:id] = thread_index

    # 工作队列为空时，等待
    loop do
      $mutex.synchronize do
        $sleeping_threads += 1
      end

      while $queue.length == 0
        sleep 1
      end

      type = keyword = nil
      # 从工作队列获取信息
      $mutex.synchronize do
        type, keyword = $queue.pop
      $sleeping_threads -= 1
      end
      p "Thread[#{thread_index}] poped from queue [#{type}, #{CGI::unescape(keyword)}], queue.length = #{$queue.length}"
      # 如果获取的工作类型是:shutdown, 则退出现在的这个线程
      Thread.exit if type == :shutdown
      # 根据工作类型，获取相应的模块类
      crawler_model = $crawler_map[type]
      # 从模块类生成实例对象
      crawler = crawler_model.new(keyword, $queue)
      # 爬取内容,解析,及后续操作
      crawler.fetch
    end
  end
end

# 子线程工作完成后，退出主线程
$threads.map(&:join)
