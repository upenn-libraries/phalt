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
