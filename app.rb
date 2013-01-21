class RokugaApp < Sinatra::Base

  get "/" do
    send_file File.join('public', 'index.html')
  end

  get "/css/rokuga.css" do
    scss :rokuga
  end

end
