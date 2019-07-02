#!/usr/bin/env ruby


require 'sinatra'
require 'open-uri'
require 'net/http'

require 'pry' if development?

MEGABYTE = 1024 * 1024

class File

  def each_chunk(chunk_size = MEGABYTE)
    yield read(chunk_size) until eof?
  end

end

class Phalt

  def self.harvest(args, harvest_type)
    payload = ''
    header_type = ''
    case harvest_type
      when 'oai'
        path = "#{ENV['OAI_PMH']}?#{args}"
      when 'iiif'
        return '' if args[:splat].nil?
        image = args[:splat].first
        if image.end_with?('/manifest')
          id = image.rpartition('/').first
          header_type = 'application/json'
          path = "#{ENV['MARMITE_BASE']}/#{id}/show?format=#{ENV['MARMITE_FORMAT']}"
        else
          image_patterns = %w[default.jpg gray.jpg color.jpg bitonal.jpg]
          arg_parts = Rack::Utils.escape_html(image).split("&#x2F;")
          bucket, image = arg_parts.shift(2)
          if image_patterns.member?(arg_parts.last)
            header_type = 'image/jpeg'
            path = "#{ENV['IIIF']}#{bucket}%2F#{image}/#{arg_parts.join('/')}"
          else
            header_type = 'text/json'
            path = "#{ENV['IIIF']}#{bucket}%2F#{image}/info.json"
          end
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

  configure do
    set :protection, :except => [:json_csrf]
  end

  def load_from_colenda(resource, &block)
    hostname = ENV['DOWNLOAD_LINK']
    port = ENV['DOWNLOAD_PORT']
    http = Net::HTTP.new(hostname,port)
    http.start do |get_call|
      req = Net::HTTP::Get.new(resource)
      get_call.request(req) do |origin_response|
        origin_response.read_body(&block)
      end
    end
  end

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

  get '/iiif/image/*' do
    return 'No IIIF image serving endpoint configured' if ENV['IIIF'].nil?
    payload, header = Phalt.harvest(params, 'iiif')
    content_type(header)

    # TODO: make more restrictive or configurable
    headers("Access-Control-Allow-Origin"  => "*")
    payload
  end

  get '/iiif/2/*' do
    return 'No IIIF image serving endpoint configured' if ENV['IIIF'].nil?
    payload, header = Phalt.harvest(params, 'iiif')
    content_type(header)

    # TODO: make more restrictive or configurable
    headers("Access-Control-Allow-Origin"  => "*")
    payload
  end

  get '/download/?' do
    return 'No download endpoint configured' if ENV['DOWNLOAD'].nil?

    #uri = "/ark99999fk49c8625j/SHA256E-s202222738--1c93595f347a69d0ca87ecdfe2e2aa170a0bebb02777ec2553a48a0c3a080cca.warc.gz"
    #filename = "ARCHIVEIT-9445-MONTHLY-JOB805439-0-SEED1430409-20190320210651591-00000-rq3stdlp.warc.gz"

    stream do |obj|
      load_from_ceph(uri) do |chunk|
        obj << chunk
      end
    end

  end

  get '/files/*' do
    headers_hash = {'.jpg' => 'image/jpg',
                    '.tif' => 'application/octet-stream',
                    '.gz' => 'application/octet-stream',
                    '.xml' => 'text/xml'
    }

    headers = headers_hash[File.extname(params[:splat].first)]

    content_type(headers)
    stream do |obj|
      load_from_colenda(params[:filename]) do |chunk|
        obj << chunk
      end
    end

  end


end
