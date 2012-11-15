require File.expand_path('../config/environment', __FILE__)

set :environment, ENV['RACK_ENV'].to_sym

use Rack::Session::Cookie,
  :key => 'vanilla.session',
  :path => '/',
  :secret => 'b23um2skr7rdhxokffjg24mgtk7nq8c0cqsdbpuly6919q4zxqovuj8znfe1z1r2d1ahpa2fgc35qfwpz0jjdfwe2tgn6mp1fcf',
  :expiry => Time.parse('2100-01-01')

map '/api/vanilla/v1' do
  run Vanilla::V1
end
