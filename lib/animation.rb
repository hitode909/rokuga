require 'RMagick'

class Animation
  def initialize
    @out = Magick::ImageList.new
    @out.iterations = 0
  end

  def add_frame(blob)
    image = Magick::Image.from_blob(blob)
    @out.push image.first
  end

  def set_delay delay
    @delay = delay
  end

  def to_blob
    to_write = @out.optimize_layers(Magick::OptimizeTransLayer).deconstruct
    to_write.delay = @delay if @delay
    to_write.write("out.gif")
    open("out.gif").read
  end
end


