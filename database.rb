#!/usr/bin/env ruby
# encoding: utf-8

require 'sequel'
require './config'


CACHE = {}
Sequel::Model.plugin :caching, CACHE, ttl: 60

#db_options = {max_connections: 5, encoding: 'UTF-8'}
db_options = {}

username = Configs.get('db.user')
password = Configs.get('db.pass')
dbhost = Configs.get('db.host')
db = Configs.get('db.database')
DB = Sequel.connect("mysql2://#{username}:#{password}@#{dbhost}/#{db}", db_options)
DB.convert_tinyint_to_bool = false
