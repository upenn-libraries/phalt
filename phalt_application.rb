#!/usr/bin/env ruby


require 'sinatra'
require 'open-uri'

require 'pry' if development?

class Phalt

  def self.harvest(args, harvest_type)
    payload = ''
    header_type = ''
    case harvest_type
      when 'oai'
        path = "#{ENV['OAI_PMH']}?#{args}"
      when 'iiif'
        return '' if args[:image].nil?
        image_patterns = %w[default.jpg gray.jpg color.jpg bitonal.jpg]
        arg_parts = Rack::Utils.escape_html(args[:image]).split("&#x2F;")
        bucket, image = arg_parts.shift(2)
        if image_patterns.member?(arg_parts.last)
          header_type = 'image/jpeg'
          path = "#{ENV['IIIF']}#{bucket}%2F#{image}/#{arg_parts.join('/')}"
        else
          header_type = 'text/json'
          path = "#{ENV['IIIF']}#{bucket}%2F#{image}/info.json"
        end
      else
        return ''
    end

    begin
      open(path) { |io| payload = io.read }
    rescue => exception
      return "#{exception.message} returned by source"
    end

    if path.end_with?('info.json')
      payload.gsub!(ENV['IIIF'], ENV['IIIF_BASE'])
    end

    return payload, header_type
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
    return 'No IIIF image serving endpoint configured' if ENV['IIIF'].nil?
    payload, header = Phalt.harvest(params, 'iiif')
    content_type(header)
    payload
  end


end