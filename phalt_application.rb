# #!/usr/bin/env ruby

require 'sinatra'
require 'open-uri'
require 'net/http'
require 'mime/types'
require './lib/phalt'

class PhaltApplication < Sinatra::Base

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

  get '/?' do
    content_type('text/html')
    'Welcome to Phalt'
  end

  get '/oai-pmh/?' do
    content_type('text/html')
    'OAI-PMH endpoint'
  end

  get '/oai-pmh/oai/?' do
    halt(500, 'No OAI-PMH endpoint configured') if ENV['OAI_PMH'].nil?

    content_type('text/xml')
    Phalt.harvest(URI.encode_www_form(params), 'oai')
  end

  get '/iiif/image/*' do
    halt(500, 'No IIIF image serving endpoint configured') if ENV['IIIF'].nil?

    payload, header = Phalt.harvest(params, 'iiif')
    content_type(header)

    # TODO: make more restrictive or configurable
    headers('Access-Control-Allow-Origin' => '*')
    payload
  end

  get '/iiif/2/*' do
    halt(500, 'No IIIF image serving endpoint configured') if ENV['IIIF'].nil?

    payload, header = Phalt.harvest(params, 'iiif')
    content_type(header)

    # TODO: make more restrictive or configurable
    headers('Access-Control-Allow-Origin' => '*')
    payload
  end

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
    headers(ceph_headers.select { |k, _| %w[last-modified etag].include? k })

    # get MIME type for original file, if possible
    mime_type = MIME::Types.type_for(file)&.first
    content_type(mime_type) if mime_type
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
