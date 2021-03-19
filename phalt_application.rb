#!/usr/bin/env ruby


require 'sinatra'
require 'open-uri'
require 'net/http'

require './lib/phalt'

# require 'pry' if development?

MEGABYTE = 1024 * 1024

class File
  def each_chunk(chunk_size = MEGABYTE)
    yield read(chunk_size) until eof?
  end
end

class PhaltApplication < Sinatra::Base

  CONTENT_TYPE_MAPPING = {
    '.jpg' => 'image/jpg',
    '.jpeg' => 'image/jpeg',
    '.tif' => 'application/octet-stream',
    '.gz' => 'application/octet-stream',
    '.xml' => 'text/xml'
  }.freeze
  
  configure do
    set :protection, except: [:json_csrf]
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

  def load_from_ceph(url, &block)
    http = Net::HTTP.new(ENV['STORAGE_HOST'], 443)
    http.use_ssl = true
    http.start do |get_call|
      req = Net::HTTP::Get.new(url)
      get_call.request(req) do |origin_response|
        origin_response.read_body(&block)
      end
    end
  end

  helpers do
    def url(url_fragment)
      port = request.port.nil? ? '' : ":#{request.port}"
      "#{request.scheme}://#{request.host}#{port}/#{url_fragment}"
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
    headers('Access-Control-Allow-Origin'  => '*')
    payload
  end

  get '/iiif/2/*' do
    return 'No IIIF image serving endpoint configured' if ENV['IIIF'].nil?
    payload, header = Phalt.harvest(params, 'iiif')
    content_type(header)

    # TODO: make more restrictive or configurable
    headers('Access-Control-Allow-Origin'  => '*')
    payload
  end

  # get '/download/?' do
  #   return 'No download endpoint configured' if ENV['DOWNLOAD'].nil?
  #
  #   #uri = "/ark99999fk49c8625j/SHA256E-s202222738--1c93595f347a69d0ca87ecdfe2e2aa170a0bebb02777ec2553a48a0c3a080cca.warc.gz"
  #   #filename = "ARCHIVEIT-9445-MONTHLY-JOB805439-0-SEED1430409-20190320210651591-00000-rq3stdlp.warc.gz"
  #
  #   stream do |obj|
  #     load_from_ceph(uri) do |chunk|
  #       obj << chunk
  #     end
  #   end
  #
  # end

  get '/download/:bucket/:file' do |bucket, file|
    filename = params[:filename] || file
    disposition = params[:disposition] || 'attachment'

    ceph_url = "#{bucket}/#{file}"

    # do HEAD request to get headers and confirm file exists
    http = Net::HTTP.new(ENV['STORAGE_HOST'], 443)
    http.use_ssl = true
    begin
      ceph_headers = http.start do |h|
        h.head(ceph_url).to_hash
      end
      headers(ceph_headers.select { |k, _| %w[content-length last-modified etag].include? k })
    rescue StandardError => _e # TODO: more specific exception
      halt 404
    end

    file_extension = File.extname file
    destination_filename_extension = File.extname filename

    # fail if attempting to change extension with filename param
    if file_extension != destination_filename_extension
      halt 500 # report error message?
    elsif !CONTENT_TYPE_MAPPING.key?(file_extension)
      halt 500 # report error?
    else
      content_type CONTENT_TYPE_MAPPING[file_extension]
    end

    attachment filename, disposition

    stream do |object|
      load_from_ceph(ceph_url) do |chunk|
        object << chunk
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
