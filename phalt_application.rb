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

  # Compute a final filename for downloading
  # Prohibits altering file extension with filename param
  # @param [String] file
  # @param [String, nil] desired_filename
  def filename_from(file, desired_filename = nil)
    return file unless desired_filename

    # don't allow the file extension to me modified for security reasons and to avoid issues with download file
    halt 500, 'Don\'t include an extension in the filename param' unless File.extname(desired_filename).empty?

    desired_filename + File.extname(file)
  end

  # Pull file from Ceph
  # @param [URI] uri
  def load_from_ceph(uri, &block)
    conn = Net::HTTP.new(ENV['STORAGE_HOST'], 443)
    conn.use_ssl = true
    conn.start do |http|
      req = Net::HTTP::Get.new(uri)
      http.request(req) do |origin_response|
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

  # Stream a download from Ceph, setting filename to something more user-friendly with
  # param :filename : should be the basename (no extname) for the file as it will be downloaded
  # param :disposition : for something other than 'attachment'
  # Returns `404` if file not found in Ceph
  # Returns `500` if PHALT error (unsupported file type, misconfiguration)
  # Returns `400` for other Ceph error
  get '/download/:bucket/:file' do |bucket, file|
    halt 500, 'No STORAGE_HOST configured' if ENV['STORAGE_HOST'].nil?

    disposition = params[:disposition] || 'attachment'
    filename = filename_from file, params[:filename]

    ceph_file_uri = URI("https://#{ENV['STORAGE_HOST']}/#{bucket}/#{file}")

    # do HEAD request to get headers and confirm file exists
    http = Net::HTTP.new(ENV['STORAGE_HOST'], 443)
    http.use_ssl = true
    response = http.start { |h| h.head(ceph_file_uri) }
    ceph_headers = case response.code
                   when '200'
                     response.to_hash
                   when '404'
                     halt 404, 'File not found'
                   else
                     halt 400, 'Problem retrieving from Ceph'
                   end
    headers(ceph_headers.select { |k, _| %w[content-length last-modified etag].include? k })

    halt 500, 'File type is not configured for downloading' unless CONTENT_TYPE_MAPPING.key?(File.extname(filename))
    content_type CONTENT_TYPE_MAPPING[File.extname(filename)]
    attachment filename, disposition

    stream do |object|
      load_from_ceph(ceph_file_uri) do |chunk|
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
