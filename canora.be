# @name    Canora
# @desc    Karaoke for your clock: the lyrics of the song that is playing, in time with the music. Home Assistant (or anything else) sends the track and its playback position over MQTT, the synced lyrics come from LRCLIB.
# @author  exradice
# @version 1.0.0
# @display 52x16
# @config prefix        text   "MQTT prefix of this clock" default="" help="Required. The same prefix as in this clock's MQTT settings, e.g. awtrix. Canora listens on <prefix>/data/canora."
# @config topic         text   "Custom topic (optional)" default="" help="Only to listen somewhere other than <prefix>/data/canora"
# @config offset        number "Offset"                 default=0 min=-3000 max=3000 unit=ms help="Positive values show the lyrics earlier, to make up for speaker delay"
# @config color_pending color  "Not yet sung"           default=#A0A0A0 group="Colors"
# @config color_sung    color  "Sung"                   default=#FFB000 group="Colors"
# @config color_title   color  "Title during intros and solos" default=#484848 group="Colors"

# Canora - https://github.com/exradice/canora
# Copyright (c) 2026 exradice. MIT License.
#
# Expected message (retained), times in milliseconds, position_ts since 1970 (UTC).
# Without position_ts (0 or missing) the script counts from when the song first arrives:
# {"enabled": true, "state": "playing", "id": "spotify:track:...", "artist": "...", "title": "...",
#  "album": "...", "duration": 180000, "position": 4598, "position_ts": 1793087239732}
#
# Layout: every lyrics line is wrapped at word boundaries into display rows. The top row is the one
# being sung, the row below is what comes next. When the top row is done, everything moves up.

import json
import string

class Canora
  var enabled, state, song, artist, title, duration, position, position_ts
  var lyr         # '' | 'loading' | 'ok' | 'none'
  var times       # start time of each lyrics line in ms
  var lines       # text of each lyrics line, "" = instrumental part
  var idx         # current lyrics line, -1 before the first one
  var active      # enabled, music playing, lyrics loaded
  var holding     # this script holds the rotation
  var skipped     # song for which someone moved on
  # Wrapping, nil until the first draw() after loading
  var l_row0, l_n, l_dur                           # per lyrics line: first row, glyphs, fill duration
  var r_line, r_a, r_b, r_text, r_starts, r_w      # per row; r_text nil = instrumental part
  var r_k, r_parts                                 # per row: last drawn state
  var top, anim_t0                                 # top row, start of the move up

  def init()
    self.enabled = false
    self.state = ""
    self.song = ""
    self.artist = ""
    self.title = ""
    self.duration = 0
    self.position = 0
    self.position_ts = 0
    self.holding = false
    self.skipped = ""
    self.active = false
    self.reset()
  end

  # A number from JSON, 0 for null or anything else
  def num(v)
    return type(v) == 'int' || type(v) == 'real' ? int(v) : 0
  end

  def cfg(key, default)
    var v = nil
    try v = store.get(key) except .. end
    return v != nil ? v : default
  end

  # The clock's own MQTT prefix is not readable from a script, so it is a setting
  def topic()
    var custom = str(self.cfg("topic", ""))
    if size(custom) > 0 return custom end
    var prefix = str(self.cfg("prefix", ""))
    return size(prefix) > 0 ? prefix + "/data/canora" : ""
  end

  def setup()
    var topic = self.topic()
    if size(topic) > 0
      mqtt.subscribe(topic, / t, payload -> self.on_data(payload))
      log("Canora: listening on " + topic)
    else
      log("Canora: set the MQTT prefix of this clock in the app settings")
    end
  end

  def on_data(payload)
    try
      var d = json.load(str(payload))
      if isinstance(d, map)
        self.enabled = d.find('enabled') == true
        self.state = str(d.find('state', ""))
        self.artist = str(d.find('artist', ""))
        self.title = str(d.find('title', ""))
        self.duration = self.num(d.find('duration'))
        var song = str(d.find('id', ""))
        if song == "" song = self.artist + "|" + self.title end
        var is_new = song != self.song
        var ts = self.num(d.find('position_ts'))
        if ts > 0
          self.position = self.num(d.find('position'))
          self.position_ts = ts
        elif is_new || self.position_ts <= 0
          # The player reports no position: count from the moment the song shows up here.
          # Pausing then shifts the lyrics, the README calls this the approximate mode.
          self.position = 0
          self.position_ts = epoch_ms() >= 0 ? epoch_ms() : 0
        end
        if is_new
          self.song = song
          self.reset()
        end
        # Without a duration (live radio, for example) a lookup would only find a wrong match
        if self.enabled && self.lyr == "" && self.title != ""
          if self.duration > 0
            self.load()
          elif is_new
            log("Canora: " + self.title + ": no duration, skipped (live stream?)")
          end
        end
      end
    except ..
    end
    self.check()
  end

  def reset()
    self.lyr = ""
    self.times = []
    self.lines = []
    self.idx = -1
    self.r_line = nil
    self.top = -1
    self.anim_t0 = 0
  end

  # ---- Lyrics from LRCLIB ----

  def enc(s)
    var out = ""
    var plain = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
    var n = size(s)
    var i = 0
    while i < n
      var c = s[i]
      if string.find(plain, c) >= 0
        out += c
      else
        out += string.format("%%%02X", string.byte(c))
      end
      i += 1
    end
    return out
  end

  # Title without additions like " - Remastered 2011" or " (feat. ...)"
  def short(s)
    var i = string.find(s, " - ")
    if i > 0 s = s[0 .. i - 1] end
    i = string.find(s, " (")
    if i > 0 s = s[0 .. i - 1] end
    return s
  end

  def fetch(url, step, attempt)
    var song = self.song
    http.get(url, / b, st -> self.on_reply(song, step, attempt, url, b, st),
             {'cap': step == 3 ? 262144 : 65536,
              'headers': {'User-Agent': "Canora/1.0.0 (+https://github.com/exradice/canora)"}})
  end

  def url_get(title)
    return "https://lrclib.net/api/get?artist_name=" + self.enc(self.artist) +
           "&track_name=" + self.enc(title) +
           "&duration=" + str((self.duration + 500) / 1000)
  end

  # Step 1: exact title, 2: shortened title, 3: search
  def load()
    self.lyr = "loading"
    self.fetch(self.url_get(self.title), 1, 1)
  end

  def on_reply(song, step, attempt, url, b, st)
    if song != self.song return end
    var ok = false
    var why = "status " + str(st)
    if b != nil && st == 200
      why = "no synced lyrics"
      try
        var d = json.load(b)
        if step < 3 && isinstance(d, map)
          ok = self.take(d.find('syncedLyrics'))
        elif isinstance(d, list)
          ok = self.take(self.pick(d))
        end
      except .. as e, m
        why = str(e) + " " + str(m) + ", " + str(size(b)) + " B"
      end
    elif b == nil && st == 200
      why = "reply dropped (memory?)"
    end
    log("Canora: " + self.title + " step " + str(step) + "/" + str(attempt) + ": " +
        (ok ? "ok, " + str(size(self.times)) + " lines" : why))
    if ok return end
    # LRCLIB often answers the first request for a song it has not cached yet with 503, and the
    # second request returns the lyrics. Network errors (status 0) get another try as well.
    if (st == 0 || st >= 500) && attempt < 3
      timer.after(2000 * attempt, / -> self.retry(song, url, step, attempt + 1))
      return
    end
    var short = self.short(self.title)
    if step == 1 && short != self.title
      self.fetch(self.url_get(short), 2, 1)
    elif step < 3
      self.fetch("https://lrclib.net/api/search?track_name=" + self.enc(short) +
                 "&artist_name=" + self.enc(self.artist), 3, 1)
    else
      self.lyr = "none"
      self.check()
    end
  end

  def retry(song, url, step, attempt)
    if song == self.song self.fetch(url, step, attempt) end
  end

  # From the search results, the one with synced lyrics and the closest duration
  def pick(results)
    var best = nil
    var gap = 10000
    for e: results
      if isinstance(e, map) && type(e.find('syncedLyrics')) == 'string'
        var a = int(real(e.find('duration', 0)) * 1000) - self.duration
        if a < 0 a = -a end
        if a < gap
          gap = a
          best = e['syncedLyrics']
        end
      end
    end
    return best
  end

  def take(lrc)
    if type(lrc) != 'string' || size(lrc) == 0 return false end
    var times = []
    var lines = []
    for l: string.split(lrc, "\n")
      var close = string.find(l, "]")
      if size(l) > 0 && l[0] == "[" && close > 1
        var stamp = l[1 .. close - 1]
        var colon = string.find(stamp, ":")
        if colon > 0
          var ms = int(stamp[0 .. colon - 1]) * 60000 +
                   int(real(stamp[colon + 1 .. size(stamp) - 1]) * 1000 + 0.5)
          var t = close + 1 < size(l) ? l[close + 1 .. size(l) - 1] : ""
          while size(t) > 0 && t[0] == " "
            t = size(t) > 1 ? t[1 .. size(t) - 1] : ""
          end
          while size(t) > 0 && (t[-1] == "\r" || t[-1] == " ")
            t = size(t) > 1 ? t[0 .. size(t) - 2] : ""
          end
          times.push(ms)
          lines.push(t)
        end
      end
    end
    if size(times) == 0 return false end
    self.reset()
    self.times = times
    self.lines = lines
    self.lyr = "ok"
    self.check()
    return true
  end

  # ---- Wrapping ----

  # Byte offsets where a glyph starts (UTF-8)
  def glyphs(s)
    var g = []
    var j = 0
    while j < size(s)
      if (string.byte(s[j]) & 0xC0) != 0x80 g.push(j) end
      j += 1
    end
    return g
  end

  # Glyphs a to b-1 of s
  def part(s, g, a, b)
    var stop = b < size(g) ? g[b] : size(s)
    return stop > g[a] ? s[g[a] .. stop - 1] : ""
  end

  def add_row(i, a, b, txt)
    self.r_line.push(i)
    self.r_a.push(a)
    self.r_b.push(b)
    self.r_text.push(txt)
    self.r_starts.push(txt != nil ? self.glyphs(txt) : [])
    self.r_w.push(txt != nil ? text_width(txt) : 0)
    self.r_k.push(-1)
    self.r_parts.push(nil)
  end

  def wrap()
    var w = width()
    self.l_row0 = []
    self.l_n = []
    self.l_dur = []
    self.r_line = []
    self.r_a = []
    self.r_b = []
    self.r_text = []
    self.r_starts = []
    self.r_w = []
    self.r_k = []
    self.r_parts = []
    self.add_row(-1, 0, 0, nil)   # intro until the first line
    var i = 0
    while i < size(self.lines)
      var s = self.lines[i]
      var g = self.glyphs(s)
      var n = size(g)
      self.l_row0.push(size(self.r_line))
      self.l_n.push(n)
      # About eight glyphs per second, never past the start of the next line
      var until = i + 1 < size(self.times) ? self.times[i + 1] - self.times[i] : 5000
      var d = n * 125
      if d < 1000 d = 1000 end
      if d > until d = until end
      self.l_dur.push(d > 0 ? d : 1)
      if n == 0
        self.add_row(i, 0, 0, nil)
      end
      var a = 0
      while a < n
        while a < n && s[g[a]] == " " a += 1 end
        if a >= n break end
        # As many whole words as fit the width
        var b = -1
        var j = a
        while j < n
          var e = j
          while e < n && s[g[e]] != " " e += 1 end
          if text_width(self.part(s, g, a, e)) > w break end
          b = e
          j = e
          while j < n && s[g[j]] == " " j += 1 end
        end
        # A word that is too wide on its own is split
        if b < 0
          b = a + 1
          while b < n && text_width(self.part(s, g, a, b + 1)) <= w b += 1 end
        end
        self.add_row(i, a, b, self.part(s, g, a, b))
        a = b
      end
      i += 1
    end
  end

  # ---- Time and rotation ----

  def pos_ms()
    var now = epoch_ms()
    if now < 0 || self.position_ts <= 0 return nil end
    var t = self.position + int(self.cfg("offset", 0))
    if self.state == "playing" t += now - self.position_ts end
    return t
  end

  def check()
    var t = self.pos_ms()
    self.active = self.enabled && self.state == "playing" && self.lyr == "ok" &&
                  t != nil && (self.duration <= 0 || t < self.duration + 3000)
  end

  def loop()
    self.check()
    if self.active && !self.holding && self.skipped != self.song
      if rotation.show()
        rotation.pause()
        self.holding = true
      end
    elif !self.active && self.holding
      self.holding = false
      rotation.resume()
      rotation.next()
    end
  end

  # Whoever moves on with a button or the app gets the display back for this song
  def on_hide()
    if self.holding
      self.holding = false
      self.skipped = self.song
      rotation.resume()
    end
  end

  def should_show()
    self.check()
    return self.active
  end

  # ---- Drawing ----

  def line_at(t)
    var n = size(self.times)
    while self.idx + 1 < n && self.times[self.idx + 1] <= t self.idx += 1 end
    while self.idx >= 0 && self.times[self.idx] > t self.idx -= 1 end
    return self.idx
  end

  # Glyphs of line i that are sung by now
  def sung(i, t)
    var p = (t - self.times[i]) * 1000 / self.l_dur[i]
    if p < 0 p = 0 end
    if p > 1000 p = 1000 end
    return self.l_n[i] * p / 1000
  end

  # Row with the current position: once a row is fully sung, the next one is current
  def row_at(i, k)
    if i < 0 return 0 end
    var r = self.l_row0[i]
    while r + 1 < size(self.r_line) && self.r_line[r + 1] == i && k >= self.r_b[r] r += 1 end
    return r
  end

  def draw_row(r, y, i, k, t)
    var txt = self.r_text[r]
    var li = self.r_line[r]
    if txt == nil
      # Instrumental part: the title, in the last three seconds a countdown of dots
      if r != self.top return end
      var target = li + 1 < size(self.times) ? self.times[li + 1] : -1
      var left = target - t
      if target >= 0 && left > 0 && left <= 3000
        var dots = (left + 999) / 1000
        var x = (width() - (dots * 4 - 2)) / 2
        for j: 1 .. dots
          rect_fill(x, y - 4, 2, 2, self.cfg("color_sung", 0xFFB000))
          x += 4
        end
      else
        scroll_text(0, y, width(), self.title, self.cfg("color_title", 0x484848))
      end
      return
    end
    var n = size(self.r_starts[r])
    var kk = 0
    if li < i
      kk = n
    elif li == i
      kk = k - self.r_a[r]
      if kk < 0 kk = 0 end
      if kk > n kk = n end
    end
    if kk != self.r_k[r]
      self.r_k[r] = kk
      var off = kk < n ? self.r_starts[r][kk] : size(txt)
      self.r_parts[r] = [[off > 0 ? txt[0 .. off - 1] : "", self.cfg("color_sung", 0xFFB000)],
                         [off < size(txt) ? txt[off .. size(txt) - 1] : "", self.cfg("color_pending", 0xA0A0A0)]]
    end
    text((width() - self.r_w[r]) / 2, y, self.r_parts[r])
  end

  def draw()
    clear()
    var t = self.pos_ms()
    if self.lyr != "ok" || t == nil
      # Only visible via "Show": without lyrics the rotation skips the app
      var hint = self.lyr == "loading" ? "loading" : (self.lyr == "none" ? "no lyrics" :
                 (size(self.topic()) == 0 ? "set prefix" : "Canora"))
      text((width() - text_ink_width(hint)) / 2, 10, hint, 0x808080)
      return
    end
    if self.r_line == nil self.wrap() end
    var i = self.line_at(t)
    var k = i >= 0 ? self.sung(i, t) : 0
    var cur = self.row_at(i, k)
    var now = now_ms()
    if cur != self.top
      # One row further: move up smoothly, otherwise (seeking) jump
      self.anim_t0 = self.top >= 0 && cur == self.top + 1 ? now : 0
      self.top = cur
    end
    var shift = 0
    if self.anim_t0 > 0
      var el = now - self.anim_t0
      if el < 250
        shift = 8 - el * 8 / 250
      else
        self.anim_t0 = 0
      end
    end
    var r = cur > 0 ? cur - 1 : 0
    while r <= cur + 2 && r < size(self.r_line)
      var y = 6 + (r - cur) * 8 + shift
      if y > -2 && y < 22
        self.draw_row(r, y, i, k, t)
      end
      r += 1
    end
  end
end

return Canora()
