#!/usr/bin/env ruby
# encoding: utf-8

require 'sequel'
require './database'

class KeywordTitle < Sequel::Model(DB[:keyword_titles])
  def self.list
    ds = filter()
  end

  def self.get()
  end

end
