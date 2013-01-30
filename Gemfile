source :rubygems

gem 'rake'
gem 'thor'
gem 'sinatra', '~> 1.3.2'
gem 'sinatra-activerecord', '~> 0.1.3', :require => false
gem 'rack', '~> 1.4'
gem 'rack-contrib', '~> 1.1.0'
gem 'activerecord', '~> 3.2.2', :require => 'active_record'
gem 'pg', '~> 0.13.2'
gem 'yajl-ruby', '~> 1.1.0', :require => "yajl"
gem 'pebblebed'
gem 'petroglyph', '~> 0.0.2'
gem 'nokogiri', '~> 1.5.2'
gem 'excon', '~> 0.12.0'
gem 'norwegian_phone', '~> 0.0.10'
gem 'rest-client', '~> 1.6'
gem 'bcrypt-ruby', :require => 'bcrypt'
gem 'airbrake', '~> 3.1.4', :require => false

group :test do
  gem 'bengler_test_helper', :git => "git@github.com:bengler/bengler_test_helper.git"
  gem 'rspec', '~> 2.8'
  gem 'rack-test'
  gem 'simplecov', :require => false
  gem 'webmock'
  gem 'rack-test'
end

group :development do
  gem 'thin'
end

group :production do
  gem 'unicorn', '~> 4.3.0'
end
