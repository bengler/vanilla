require 'sinatra/activerecord/rake'
require 'bengler_test_helper/tasks' if ['development', 'test'].include?(ENV['RACK_ENV'] || ENV['RAILS_ENV'] || 'development')

task :environment do
  require './config/environment'
end

namespace :db do
  desc "bootstrap db user, recreate, run migrations"
  task :bootstrap do
    name = "vanilla"
    `createuser -sdR #{name}`
    `createdb -O #{name} #{name}_development`
    Rake::Task['db:migrate'].invoke
    Rake::Task['db:test:prepare'].invoke
  end

  task :migrate => :environment

  desc "nuke db, recreate, run migrations"
  task :nuke do
    name = "vanilla"
    `dropdb #{name}_development`
    `createdb -O #{name} #{name}_development`
    Rake::Task['db:migrate'].invoke
    Rake::Task['db:test:prepare'].invoke
  end
end
