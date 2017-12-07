#!/usr/bin/env ruby


require 'sinatra'
require 'open-uri'

require 'pry' if development?

class Phalt

  def self.harvest(args, harvest_type)
    payload = ''
    case harvest_type
      when 'oai'
        path = "#{ENV['OAI_PMH']}?#{args}"
      when 'iiif'
        return '' if args[:image].nil?
        bucket, image = Rack::Utils.escape_html(args[:image]).split("&#x2F;")
        path = "#{ENV['IIIF']}/#{bucket}%2F#{image}/info.json"
      else
        return ''
    end

    begin
      open(path) { |io| payload = io.read }
    rescue => exception
      return "#{exception.message} returned by source"
    end
    return payload
  end

  def missing_env_vars?
    return (ENV['OAI_PMH'].nil?)
  end

end

class PhaltApplication < Sinatra::Base

  helpers do
    def url(url_fragment)
      port = request.port.nil? ? '' : ":#{request.port}"
      url = "#{request.scheme}://#{request.host}#{port}/#{url_fragment}"
      return url
    end
  end


  get '/?' do
    content_type('text/html')
    'Welcome to Phalt'
  end

  get '/oai-pmh/?' do
    content_type('text/html')
    'OAI-PMH endpoint'
  end

  get '/oai-pmh/oai/?' do
    return 'No OAI-PMH endpoint configured' if ENV['OAI_PMH'].nil?
    content_type('text/xml')
    Phalt.harvest(URI.encode_www_form(params), 'oai')
  end

  get '/iiif/?' do
    return 'No IIIF image serving endpoint configured' if ENV['OAI_PMH'].nil?
    content_type('text/json')
    Phalt.harvest(params, 'iiif')
  end


end