require File.expand_path('config/site.rb') if File.exists?('config/site.rb')

require "bundler"
Bundler.require

require 'rack/contrib'
require 'yajl/json_gem'
require 'pebblebed/sinatra'
require 'sinatra/petroglyph'
require 'timeout'
require 'excon'
require 'securerandom'
require 'singleton'
require 'openssl'
require 'norwegian_phone'
require 'rest_client'
require 'logger'

ENV['RACK_ENV'] ||= "development"
environment = ENV['RACK_ENV']

Pebblebed.config do
  service :checkpoint
  service :hermes
end

unless defined?(LOGGER)
  LOGGER = Logger.new($stdout)
  LOGGER.level = Logger::INFO
end

%w(
  lib/vanilla/**/*.rb
  api/*.rb
  api/v1/*.rb
).each do |spec|
  Dir.glob(File.expand_path("../../#{spec}", __FILE__)).each do |f|
    require f
  end
end

ActiveRecord::Base.logger ||= LOGGER
ActiveRecord::Base.establish_connection(
  YAML::load(File.open(File.expand_path("../database.yml", __FILE__)))[environment])
