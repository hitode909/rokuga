require './lib/data_url'
require './lib/animation'

class RokugaApp < Sinatra::Base

  get "/" do
    send_file File.join('views', 'index.html')
  end

  post "/save" do
    delay = params[:delay].to_i
    unless delay
      halt 400, 'delay required'
    end

    frames = params[:frames]

    data_urls = frames.map{ |url|
      DataURL.parse url
    }

    animation = Animation.new
    animation.set_delay delay

    data_urls.each{|url|
      animation.add_frame url.body
    }

    DataURL.format('image/gif', animation.to_blob)
  end

  get "/css/rokuga.css" do
    scss :rokuga
  end

end
