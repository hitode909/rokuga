Rokuga = {}

Rokuga.addTaskGuard = (guard) ->
  $indicator = $ '.indicator'

  do $indicator.show

  guard.always ->
    do $indicator.hide

class Rokuga.FileHandler
  constructor: (args) ->
    @$container = args.$container
    throw "$container required" unless @$container
    @$file_input = args.$file_input
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

    @$file_input.on 'change', (jquery_event) =>
      (@readFiles (@$file_input.get 0 ).files).done (contents) =>
          ($ this).trigger 'data_url_prepared', [contents]

  readFiles: (files) ->
    read_all = do $.Deferred
    Rokuga.addTaskGuard read_all
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

Rokuga.createVideoAndWaitForLoad = (url) ->
  can_play = do $.Deferred

  $video = $ '<video>'
  $video.attr
    src: url

  $video.one 'canplay', ->
    can_play.resolve $video

  $video.one 'error', (error) ->
    can_play.fail error

  do can_play.promise

Rokuga.recordVideoAsURLList = (video, fps) ->
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

  Rokuga.addTaskGuard reached_end

  shot_timer = setInterval ->
    unless video.currentTime < video.duration
      reached_end.resolve images
      clearInterval shot_timer
    context.drawImage video, 0, 0, video.videoWidth, video.videoHeight
    images.push do canvas.toDataURL
    video.currentTime += 1/fps

  do reached_end.promise

Rokuga.createUniqueFrames = (image_urls) ->
  frames = []
  last_url = null
  for url in image_urls
    continue if url == last_url
    frame = new Rokuga.Frame(url)
    window.frame = frame
    frames.push frame

  frames

class Rokuga.Frame
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

class Rokuga.FramesPlayer
  constructor: (args) ->
    @$screen = args.$screen
    @frames = args.frames
    @currentFrame = 0
    do @setForwardMode

  play: ->
    return if @play_timer

    @currentFrame = 0
    @lastFrame = 0

    @play_timer = null

    step = =>
      (do @frames[@lastFrame].getElement).removeClass 'current'

      try_count = 0
      while try_count < @frames.length * 2
        frame = null
        @currentFrame = @getNextFrame @currentFrame
        @currentFrame = 0 if @currentFrame >= @frames.length
        @currentFrame = @frames.length-1 if @currentFrame < 0
        frame = @frames[@currentFrame]
        if @currentFrame != @lastFrame and do frame.isActive
          frame = @currentFrame
          break
        try_count++

      frameObject = @frames[if frame? then frame else @lastFrame]

      if frameObject
        @$screen.attr
          src: do frameObject.getURL

        (do frameObject.getElement).addClass 'current'

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

    Rokuga.addTaskGuard saved

    activeURLs = do @createFramesURL

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

  setForwardMode: ->
    # TODO: filter active frames first
    @getNextFrame = (frame) =>
      frame + 1

    @createFramesURL = ->
      i = 0
      actives = _.filter @frames, (frame) -> do frame.isActive
      frames = []
      while i < actives.length
        frame = actives[i]
        frames.push frame
        i++

      do frame.getURL for frame in frames

  setReverseMode: ->
    @getNextFrame = (frame) =>
      frame - 1

    @createFramesURL = ->
      actives = _.filter @frames, (frame) -> do frame.isActive
      i = actives.length-1
      frames = []
      while i >= 0
        frame = actives[i]
        frames.push frame
        i--

      do frame.getURL for frame in frames

  setComeAndGoMode: ->
    diff = 1
    @getNextFrame = (frame) =>
      diff *= -1 if frame == @frames.length - 1
      diff *= -1 if frame == 0
      frame + diff

    @createFramesURL = ->
      actives = _.filter @frames, (frame) -> do frame.isActive
      i = 0
      frames = []

      while i < actives.length
        frame = actives[i]
        frames.push frame if do frame.isActive
        i++

      i = actives.length-2
      while i > 0
        frame = actives[i]
        frames.push frame if do frame.isActive
        i--

      do frame.getURL for frame in frames

  setRandomMode: ->
    @getNextFrame = (frame) =>
      Math.floor (do Math.random * @frames.length)

    @createFramesURL = ->
      actives = _.filter @frames, (frame) -> do frame.isActive
      shuffled = _.shuffle actives
      do frame.getURL for frame in shuffled

Rokuga.saveToGallery = (url) ->
  $anchor = $ '<a>'
  $anchor.attr
    href: url
    target: '_blank'

  $img = $ '<img>'
  $img.attr
    src: url

  $anchor.prepend $img

  $gallery = $ '.gallery'
  do $gallery.show
  $gallery.prepend $anchor
  $img.one 'load', ->
    window.scrollTo 0, (do $anchor.offset).top

$ ->
  file_handler = new Rokuga.FileHandler
    $container: $ '.drop-here'
    $file_input: $ 'input[type="file"]'
  $(file_handler)
  .on 'enter', ->
    $('.drop-here').addClass 'active'
  .on 'leave', ->
    $('.drop-here').removeClass 'active'
  .on 'data_url_prepared', (event, urls) ->
    $('.drop-here').removeClass 'active'
    do $('.drop-here').remove

    (Rokuga.createVideoAndWaitForLoad urls[0]).done ($video) ->

      ($ '.sampling-preview').append $video

      (Rokuga.recordVideoAsURLList ($video.get 0), 8).done (image_urls) ->
        do $video.remove
        do $('.controllers').show
        do ($ '.player').show

        do ->
          $top_line = $ '<tr>'
          $top_line.addClass 'top-line'
          $padding = $ '<td>'
          $padding.addClass 'padding'
          $top_line.append $padding
          for i in [0..7]
            $control_item = $ '<td>'
            $control_item.addClass 'control-item'
            $checkbox = ($ '<input type="checkbox" checked>')
            $checkbox.attr 'data-index', i
            $checkbox.addClass 'row-controller'
            $control_item.append ($ '<label>').append $checkbox
            $top_line.append $control_item

          ($ '.frames').append $top_line

        frames = Rokuga.createUniqueFrames image_urls
        frame_index = 0
        $frame_line = null
        for frame in frames
          if frame_index % 8 == 0
            $frame_line = $('<tr>')
            $frame_line.addClass 'frame-line'
            $checkbox = ($ '<input type="checkbox" checked>')
            $checkbox.addClass 'column-controller'
            $padding = $ '<td>'
            $padding.addClass 'padding'
            $padding.append ($ '<label>').append $checkbox
            $frame_line.append $padding
            ($ '.frames').append $frame_line

          $frame_line.append ($ '<td>').append do frame.createElement
          frame_index++

        player = new Rokuga.FramesPlayer
          $screen: $ '.player img'
          frames: frames
        do player.play

        ($ '.padding:has(input)').click (event) ->
          return if ($ event.target).is 'input'
          ($ this).find('input').click()

        ($ '.column-controller').change ->
          $checkbox = $ this
          (($checkbox.parents '.frame-line').find '.frame-item input').prop 'checked', $checkbox.prop 'checked'

        ($ '.row-controller').change ->
          $checkbox = $ this
          ($ '.frame-line').each ->
            ($ this).find(".frame-item:eq(#{ $checkbox.attr 'data-index' }) input").prop 'checked', $checkbox.prop 'checked'

        ($ '.save-button').click ->
          (do player.saveAsDataURL).done (url) ->
            Rokuga.saveToGallery url
          .fail ->
            alert "Failed to save animation gif."

        setButtonClass = (button) ->
          ($ '.play-type-control .btn-primary').removeClass 'btn-primary'
          ($ button).addClass 'btn-primary'

        ($ '.forward-button').click ->
          setButtonClass this
          do player.setForwardMode

        ($ '.reverse-button').click ->
          setButtonClass this
          do player.setReverseMode

        ($ '.come-and-go-button').click ->
          setButtonClass this
          do player.setComeAndGoMode

        ($ '.random-button').click ->
          setButtonClass this
          do player.setRandomMode

    .fail ->
      alert "Failed to play the video."