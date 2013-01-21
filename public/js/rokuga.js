var Rokuga;
var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };
Rokuga = {};
Rokuga.addTaskGuard = function(guard) {
  var $indicator;
  $indicator = $('.indicator');
  $indicator.show();
  return guard.always(function() {
    return $indicator.hide();
  });
};
Rokuga.FileHandler = (function() {
  function FileHandler(args) {
    this.$container = args.$container;
    if (!this.$container) {
      throw "$container required";
    }
    this.bindEvents();
  }
  FileHandler.prototype.bindEvents = function() {
    return this.$container.on('dragstart', __bind(function() {
      return true;
    }, this)).on('dragover', __bind(function() {
      return false;
    }, this)).on('dragenter', __bind(function(event) {
      if (this.$container.is(event.target)) {
        ($(this)).trigger('enter');
      }
      return false;
    }, this)).on('dragleave', __bind(function(event) {
      if (this.$container.is(event.target)) {
        return ($(this)).trigger('leave');
      }
    }, this)).on('drop', __bind(function(jquery_event) {
      var event, files;
      event = jquery_event.originalEvent;
      files = event.dataTransfer.files;
      if (files.length > 0) {
        ($(this)).trigger('drop', [files]);
        (this.readFiles(files)).done(__bind(function(contents) {
          return ($(this)).trigger('data_url_prepared', [contents]);
        }, this));
      }
      return false;
    }, this));
  };
  FileHandler.prototype.readFiles = function(files) {
    var contents, i, read_all, role;
    read_all = $.Deferred();
    Rokuga.addTaskGuard(read_all);
    contents = [];
    i = 0;
    role = __bind(function() {
      var file;
      if (files.length <= i) {
        return read_all.resolve(contents);
      } else {
        file = files[i++];
        return (this.readFile(file)).done(function(content) {
          return contents.push(content);
        }).always(function() {
          return role();
        });
      }
    }, this);
    role();
    return read_all.promise();
  };
  FileHandler.prototype.readFile = function(file) {
    var read, reader;
    read = $.Deferred();
    reader = new FileReader;
    reader.onload = function() {
      return read.resolve(reader.result);
    };
    reader.onerror = function(error) {
      return read.reject(error);
    };
    reader.readAsDataURL(file);
    return read.promise();
  };
  return FileHandler;
})();
Rokuga.recordVideoAsURLList = function(video, fps) {
  var canvas, context, images, reached_end, shot_timer;
  canvas = (function() {
    var $element;
    $element = $('<canvas>');
    $element.attr({
      width: video.videoWidth,
      height: video.videoHeight
    });
    return $element.get(0);
  })();
  context = canvas.getContext('2d');
  images = [];
  reached_end = $.Deferred();
  Rokuga.addTaskGuard(reached_end);
  video.play();
  shot_timer = setInterval(function() {
    context.drawImage(video, 0, 0, video.videoWidth, video.videoHeight);
    return images.push(canvas.toDataURL());
  }, Math.floor(1000 / fps));
  ($(video)).on('ended', function() {
    clearTimeout(shot_timer);
    return reached_end.resolve(images);
  });
  return reached_end.promise();
};
Rokuga.Frame = (function() {
  function Frame(url) {
    this.url = url;
  }
  Frame.prototype.createElement = function() {
    var $label;
    this.$element = ($('<div>')).addClass('frame-item');
    $label = $('<label>');
    this.$element.append($label);
    $label.append($('<input type=checkbox checked>'));
    this.$element.css({
      'background-image': "url('" + this.url + "')"
    });
    return this.$element;
  };
  Frame.prototype.getElement = function() {
    return this.$element;
  };
  Frame.prototype.isActive = function() {
    return (this.$element.find('input')).prop('checked');
  };
  Frame.prototype.getURL = function() {
    return this.url;
  };
  return Frame;
})();
Rokuga.FramesPlayer = (function() {
  function FramesPlayer(args) {
    this.$screen = args.$screen;
    this.frames = args.frames;
    this.currentFrame = 0;
  }
  FramesPlayer.prototype.play = function() {
    var step;
    if (this.play_timer) {
      return;
    }
    this.currentFrame = 0;
    this.lastFrame = 0;
    this.play_timer = null;
    step = __bind(function() {
      var frame, try_count;
      (this.frames[this.lastFrame].getElement()).removeClass('current');
      try_count = 0;
      frame = null;
      while (try_count < this.frames.length) {
        this.currentFrame++;
        if (this.currentFrame >= this.frames.length) {
          this.currentFrame = 0;
        }
        frame = this.frames[this.currentFrame];
        if (frame.isActive()) {
          break;
        }
        try_count++;
      }
      this.$screen.attr({
        src: frame.getURL()
      });
      (frame.getElement()).addClass('current');
      this.lastFrame = this.currentFrame;
      return this.play_timer = setTimeout(step, this.getWait());
    }, this);
    return step();
  };
  FramesPlayer.prototype.stop = function() {
    clearInterval(this.play_timer);
    return this.play_timer = null;
  };
  FramesPlayer.prototype.pause = function() {
    if (this.play_timer) {
      return this.stop();
    } else {
      return this.play();
    }
  };
  FramesPlayer.prototype.getWait = function() {
    return (this.getDelay()) * 10;
  };
  FramesPlayer.prototype.getDelay = function() {
    return +($('.delay')).val();
  };
  FramesPlayer.prototype.saveAsDataURL = function() {
    var activeURLs, frame, saved;
    saved = $.Deferred();
    Rokuga.addTaskGuard(saved);
    activeURLs = (function() {
      var _i, _len, _ref, _results;
      _ref = this.frames;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        frame = _ref[_i];
        if (frame.isActive()) {
          _results.push(frame.getURL());
        }
      }
      return _results;
    }).call(this);
    $.ajax({
      type: 'POST',
      url: '/save',
      dataType: 'text',
      data: {
        delay: this.getDelay(),
        frames: activeURLs
      }
    }).done(function(gif_url) {
      return saved.resolve(gif_url);
    }).fail(function(error) {
      return saved.fail();
    });
    return saved.promise();
  };
  return FramesPlayer;
})();
$(function() {
  var file_handler;
  file_handler = new Rokuga.FileHandler({
    $container: $('.drop-here'),
    type: /^video\/$/
  });
  return $(file_handler).on('enter', function() {
    return $('.drop-here').addClass('active');
  }).on('leave', function() {
    return $('.drop-here').removeClass('active');
  }).on('data_url_prepared', function(event, urls) {
    var $video, content;
    $('.drop-here').remove();
    content = urls[0];
    $video = $('<video>');
    $video.attr({
      src: content
    });
    ($('.sampling-preview')).append($video);
    $video.one('ended', function() {
      return $video.remove();
    });
    return $video.one('canplay', function() {
      return (Rokuga.recordVideoAsURLList($video.get(0), 12)).done(function(image_urls) {
        var frame, frames, last_url, player, url, _i, _len;
        $('.controllers').show();
        $video.remove();
        frames = [];
        last_url = null;
        for (_i = 0, _len = image_urls.length; _i < _len; _i++) {
          url = image_urls[_i];
          if (url === last_url) {
            continue;
          }
          frame = new Rokuga.Frame(url);
          window.frame = frame;
          frames.push(frame);
          ($('.frames')).append(frame.createElement());
          last_url = url;
        }
        ($('.player')).show();
        player = new Rokuga.FramesPlayer({
          $screen: $('.player img'),
          frames: frames
        });
        player.play();
        ($('.pause-button')).click(function() {
          return player.pause();
        });
        return ($('.save-button')).click(function() {
          return (player.saveAsDataURL()).done(function(url) {
            var $gallery, $img;
            $img = $('<img>');
            $img.attr({
              src: url
            });
            $gallery = $('.gallery');
            $gallery.show();
            $gallery.append($img);
            return $img.on('click', function() {
              return window.open($img.attr('src'));
            });
          });
        });
      });
    });
  });
});