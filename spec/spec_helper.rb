ENV['RACK_ENV'] ||= 'test'
Bundler.require(:test)

# Simplecov must be loaded before everything else
require 'simplecov'
SimpleCov.add_filter 'spec'
SimpleCov.add_filter 'config'
SimpleCov.start

require File.expand_path('../../config/environment', __FILE__)

require 'rspec'
require 'rspec/autorun'
require 'rack/test'
require 'excon'
require 'webmock/rspec'
require 'stringio'
require 'pp'

Dir.glob(File.expand_path('../helpers/*.rb', __FILE__)).each do |f|
  require f
end

LOGGER.level = Logger::FATAL

set :environment, :test

RSpec.configure do |config|
  config.mock_with :rspec

  config.include UrlHelper
  config.include SessionHelper
  config.include RequestHelper

  config.before :each do
    WebMock.reset!

    clear_cookies if self.respond_to?(:clear_cookies)

    checkpoint_session_key_cookie! if self.respond_to?(:rack_mock_session)
  end
  
  config.around :each do |block|
    abort_class = Class.new(Exception) {}
    begin
      ActiveRecord::Base.transaction do
        block.call
        raise abort_class
      end
    rescue abort_class
    end
  end
end

class TestVanillaV1 < Vanilla::V1
  # Same cookie as in config.ru, but without secret
  use Rack::Session::Cookie,
    :key => 'vanilla.session',
    :path => '/',
    :expiry => Time.parse('2100-01-01')
end
