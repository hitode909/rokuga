require './lib/data_url'
require './lib/animation'

class RokugaApp < Sinatra::Base

  get "/" do
    send_file File.join('public', 'index.html')
  end

  post "/save" do
    wait = params[:wait].to_i
    unless wait
      halt 400, 'wait required'
    end

    frames = params[:frames]

    data_urls = frames.map{ |url|
      DataURL.parse url
    }

    p "#{frames.length} frames, wait = #{wait}"

    animation = Animation.new
    animation.set_delay [(wait/10).to_i, 1].max

    data_urls.each{|url|
      animation.add_frame url.body
    }

    animation.write

    "http://htn.to/motemen"
  end

  get "/css/rokuga.css" do
    scss :rokuga
  end

end
