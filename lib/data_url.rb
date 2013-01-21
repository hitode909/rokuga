require 'base64'

class DataURL
  attr_reader :content_type
  def self.parse(uri)
    syntax = /^data:(?<content_type>[^;]+);(?<is_base64>base64,)(?<body>.*)$/
    matched = uri.match syntax
    raise "not data URI" unless matched
    self.new matched[:content_type], !!matched[:is_base64], matched[:body]
  end

  def initialize(content_type, is_base64, body)
    @content_type = content_type
    @is_base64 = is_base64
    @body = body
  end

  def base64?
    @is_base64
  end

  def body
    if base64?
      Base64.decode64 @body
    else
      @body
    end
  end
end
