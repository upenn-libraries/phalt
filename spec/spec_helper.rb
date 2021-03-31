# Adapted from https://github.com/sinatra/sinatra-recipes/blob/master/testing/rspec.md

require 'rack/test'
require 'rspec'
require 'webmock/rspec'

ENV['RACK_ENV'] = 'test'

require File.expand_path '../../phalt_application.rb', __FILE__

module RSpecMixin
  include Rack::Test::Methods
  def app() PhaltApplication end
end

RSpec.configure do |c|
  c.include RSpecMixin
end