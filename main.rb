#!/usr/bin/env ruby
# encoding: utf-8

require 'thread'
require 'cgi'
require './models/keyword'
require './models/keyword_title'
require './crawlers/keyword_crawler'
require './crawlers/keyword_title_crawler'

# run it like this: ruby main.rb "中国"

#ARGV
if ARGV == nil or ARGV.length < 1
  p "--- sample ---"
  p "run it like this: ruby main.rb '中国' "
  p "help: 中国-> initial keyword"
  exit(0)
end

# 初始化全局变量
Thread.current[:id] = 'M'
# 工作队列
$working_queue = Queue.new
# 缓冲队列，爬取的结果先放到缓冲队列，再由另外一个线程写到数据库
$buffer_queue = Queue.new
# 锁
$mutex = Mutex.new
# 爬行类型对应的爬行模块类
$crawler_map = {keyword: KeywordCrawler, title: KeywordTitleCrawler}

# 将第一个关键字放到工作队列
$initial_keyword = ARGV[0]
$working_queue << [:keyword, CGI::escape($initial_keyword)]

# 初始化工作线程
$threads = []
# 要开启的线程数量
$thread_num = Configs.get('app.threads')
# 等待中的线程数量
$waiting_threads = 0

$thread_num.times do |thread_index|
  $threads << Thread.new do
    p "Thread[#{thread_index}] starting ..."
    Thread.current[:id] = thread_index

    # 工作队列为空时，等待
    loop do
      $mutex.synchronize do
        $waiting_threads += 1
      end

      while $working_queue.length == 0
        sleep 1
      end

      type = keyword = nil
      # 从工作队列获取信息
      $mutex.synchronize do
        type, keyword = $working_queue.pop
        $waiting_threads -= 1
      end

      p "Thread[#{thread_index}] poped from working_queue [:#{type}, #{CGI::unescape(keyword)}], working_queue.length = #{$working_queue.length}"
      # 如果获取的工作类型是:shutdown, 则退出现在的这个线程
      Thread.exit if type == :shutdown
      # 根据工作类型，获取相应的模块类
      crawler_model = $crawler_map[type]
      # 从模块类生成实例对象
      crawler = crawler_model.new(keyword, $buffer_queue)
      # 爬取内容,解析,及后续操作
      crawler.fetch
    end
  end
end

save_thread = Thread.new do
  loop do
    if $buffer_queue.length > 0
      type, hash = $buffer_queue.pop
      if type == :title
        KeywordTitle.insert(hash)
      elsif Keyword.count >= Configs.get('app.word_limit')
        $thread_num.times { $working_queue << [:shutdown, 'nil'] }
        Thread.exit
      elsif Keyword.filter(hash).empty?
        Keyword.insert(hash)
        $working_queue << [:keyword, hash[:keyword]]
        $working_queue << [:title, hash[:keyword]]
        p "Thread[S] pushed to working_queue [:title, #{CGI::unescape(hash[:keyword])}]"
      end
    else
      $mutex.synchronize do
        # 如果所有的子线程都在等待，而队列内容为空，则退出整个程序
        if $waiting_threads == $thread_num and $working_queue.length == 0 and $buffer_queue.length == 0
          $thread_num.times { $working_queue << [:shutdown, 'nil'] }
          Thread.exit
        end
      end
      sleep 1
    end
  end
end


# 子线程工作完成后，退出主线程
$threads.map(&:join)
save_thread.join
