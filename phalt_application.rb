#!/usr/bin/env ruby


require 'sinatra'
require 'active_support/core_ext/string/output_safety'
require 'open-uri'

require 'pry' if development?

class Phalt

  def self.harvest(args, harvest_type)
    payload = ''
    case harvest_type
      when 'oai'
        path = "http://colenda-dev.library.upenn.int:8983/solr/blacklight-core/oai?#{args}"
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

end

class PhaltApplication < Sinatra::Base

  helpers do
    def url(url_fragment)
      port = request.port.nil? ? '' : ":#{request.port}"
      url = "#{request.scheme}://#{request.host}#{port}/#{url_fragment}"
      return url
    end
  end


  get '/oai-pmh/oai/?' do
    content_type('text/xml')
    Phalt.harvest(URI.encode_www_form(params), 'oai')
  end


end