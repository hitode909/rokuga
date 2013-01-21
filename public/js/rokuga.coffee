class FileHandler
  constructor: (args) ->
    @$container = args.$container
    throw "$container required" unless @$container
    @bindEvents()

  bindEvents: ->
    @$container
    .on 'dragstart', =>
      true
    .on 'dragover', =>
      false
    .on 'dragenter', (event) =>
      if @$container.is event.target
        ($ this).trigger 'enter'
      false
    .on 'dragleave', (event) =>
      if @$container.is event.target
        ($ this).trigger 'leave'
    .on 'drop', (jquery_event) =>
      event = jquery_event.originalEvent
      files = event.dataTransfer.files
      if files.length > 0
        ($ this).trigger 'drop', [files]

        (@readFiles files).done (contents) =>
          ($ this).trigger 'data_url_prepared', [contents]

      false

  readFiles: (files) ->
    read_all = do $.Deferred
    contents = []
    i = 0

    role = =>
      if files.length <= i
        read_all.resolve contents
      else
        file = files[i++]
        (@readFile file).done (content) ->
          contents.push content
        .always ->
          do role

    do role

    do read_all.promise

  readFile: (file) ->
    read = do $.Deferred
    reader = new FileReader
    reader.onload = ->
      read.resolve reader.result
    reader.onerror = (error) ->
      read.reject error
    reader.readAsDataURL file

    do read.promise

RecordVideoAsURLList = (video, fps) ->
  # video must be playable
  canvas = do ->
    $element = $ '<canvas>'
    $element.attr
      width: video.videoWidth
      height: video.videoHeight
    $element.get 0
  context = canvas.getContext '2d'

  images = []

  reached_end = do $.Deferred

  do video.play

  shot_timer = setInterval ->
    context.drawImage video, 0, 0, video.videoWidth, video.videoHeight
    images.push do canvas.toDataURL
  , Math.floor 1000/fps

  ($ video).on 'ended', ->
    clearTimeout shot_timer
    reached_end.resolve images

  do reached_end.promise

class Frame
  constructor: (url) ->
    @url = url

  createElement: ->
    @$element = ($ '<div>').addClass 'frame-item'
    $label = $ '<label>'
    @$element.append $label
    $label.append $ '<input type=checkbox checked>'

    @$element.css
      'background-image': "url('#{@url}')"
    @$element

  getElement: ->
    @$element

  isActive: ->
    (@$element.find 'input').prop 'checked'

  getURL: ->
    @url

class FramesPlayer
  constructor: (args) ->
    @$screen = args.$screen
    @frames = args.frames
    @currentFrame = 0

  play: ->
    return if @play_timer

    @currentFrame = 0
    @lastFrame = 0

    @play_timer = null

    step = =>
      (do @frames[@lastFrame].getElement).removeClass 'current'

      try_count = 0
      frame = null
      while try_count < @frames.length
        @currentFrame++
        @currentFrame = 0 if @currentFrame >= @frames.length
        frame = @frames[@currentFrame]
        break if frame.isActive()
        try_count++

      @$screen.attr
        src: do frame.getURL

      (do frame.getElement).addClass 'current'

      @lastFrame = @currentFrame

      @play_timer = setTimeout step, do @getWait

    step()

  stop: ->
    clearInterval @play_timer
    @play_timer = null

  pause: ->
    if @play_timer
      do @stop
    else
      do @play

  getWait: ->
    (do @getDelay) * 10

  getDelay: ->
    + ($ '.delay').val()

  saveAsDataURL: ->
    saved = do $.Deferred

    activeURLs = (do frame.getURL for frame in @frames when frame.isActive())

    $.ajax
      type: 'POST'
      url: '/save'
      dataType: 'text'
      data:
        delay: do @getDelay
        frames: activeURLs
    .done (gif_url) ->
      saved.resolve gif_url
    .fail (error) ->
      saved.fail()

    do saved.promise

$ ->
  file_handler = new FileHandler
    $container: $('.drop-here')
    type: /^video\/$/
  $(file_handler)
  .on 'enter', ->
    $('.drop-here').addClass 'active'
  .on 'leave', ->
    $('.drop-here').removeClass 'active'
  .on 'data_url_prepared', (event, urls) ->
    do $('.drop-here').remove
    content = urls[0]
    $video = $ '<video>'
    $video.attr
      src: content

    ($ '.sampling-preview').append $video
    $video.one 'ended', ->
      $video.remove()

    $video.one 'canplay', ->
      (RecordVideoAsURLList ($video.get 0), 8).done (image_urls) ->
        do $('.controllers').show
        do $video.remove
        frames = []
        last_url = null
        for url in image_urls
          continue if url == last_url
          frame = new Frame(url)
          window.frame = frame
          frames.push frame
          ($ '.frames').append do frame.createElement
          last_url = url

        player = new FramesPlayer
          $screen: $ '.player img'
          frames: frames
        do player.play

        ($ '.pause-button').click ->
          do player.pause

        ($ '.save-button').click ->
          (do player.saveAsDataURL).done (url) ->
            $img = $ '<img>'
            $img.attr
              src: url
            ($ '.gallery').append $img

            $img.on 'click', ->
              window.open $img.attr 'src'
