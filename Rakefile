raise "Rake must not be run directly. Either run via Bundler (bundle exec rake) or via bin/rake." unless defined?(Bundler)
APP_ROOT ||= File.expand_path(File.dirname(__FILE__))
require 'corvid/rake/tasks'

# Set default task to test
task :default => :test
