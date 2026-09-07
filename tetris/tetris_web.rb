# A pure-Ruby stand-in for the part of Ruby2D that a small game touches.
#
# The real gem binds to SDL through a C extension, so it cannot load under
# koruby (no C extensions) or in wasm (no dlopen).  Nothing about the *API* is
# native, though: it is a retained list of shapes that a renderer walks.  So
# this keeps the shapes and rasterises them into a framebuffer, and the host
# drives frames and keys over stdin/stdout like the other pages here.
#
# Implemented: set, Window.update / on(:key_down, :key_held, :key_up),
# Window.width / height / frames, Rectangle, Square, Text, Font.path, show.
# Colours may be a CSS-ish name, "#rrggbb", or [r, g, b, a] floats.

module Ruby2D
  COLORS = {
    'black' => [0, 0, 0], 'white' => [255, 255, 255], 'gray' => [128, 128, 128],
    'grey' => [128, 128, 128], 'red' => [255, 0, 0], 'green' => [0, 128, 0],
    'blue' => [0, 0, 255], 'yellow' => [255, 255, 0], 'aqua' => [0, 255, 255],
    'orange' => [255, 165, 0], 'purple' => [128, 0, 128], 'brown' => [165, 42, 42],
    'fuchsia' => [255, 0, 255], 'lime' => [0, 255, 0], 'navy' => [0, 0, 128],
    'teal' => [0, 128, 128], 'olive' => [128, 128, 0], 'maroon' => [128, 0, 0],
    'silver' => [192, 192, 192], 'random' => [200, 200, 200]
  }.freeze

  # 5x7 cells in a 6x8 box: enough for the score and prompt text a game shows.
  FONT_W = 6
  FONT_H = 8
  GLYPHS = {
    ' ' => %w[00000 00000 00000 00000 00000 00000 00000],
    '0' => %w[01110 10001 10011 10101 11001 10001 01110],
    '1' => %w[00100 01100 00100 00100 00100 00100 01110],
    '2' => %w[01110 10001 00001 00010 00100 01000 11111],
    '3' => %w[11111 00010 00100 00010 00001 10001 01110],
    '4' => %w[00010 00110 01010 10010 11111 00010 00010],
    '5' => %w[11111 10000 11110 00001 00001 10001 01110],
    '6' => %w[00110 01000 10000 11110 10001 10001 01110],
    '7' => %w[11111 00001 00010 00100 01000 01000 01000],
    '8' => %w[01110 10001 10001 01110 10001 10001 01110],
    '9' => %w[01110 10001 10001 01111 00001 00010 01100],
    ':' => %w[00000 00100 00100 00000 00100 00100 00000],
    "'" => %w[00100 00100 00000 00000 00000 00000 00000],
    '-' => %w[00000 00000 00000 01110 00000 00000 00000],
    '.' => %w[00000 00000 00000 00000 00000 00110 00110],
    'A' => %w[01110 10001 10001 11111 10001 10001 10001],
    'B' => %w[11110 10001 11110 10001 10001 10001 11110],
    'C' => %w[01110 10001 10000 10000 10000 10001 01110],
    'D' => %w[11110 10001 10001 10001 10001 10001 11110],
    'E' => %w[11111 10000 11110 10000 10000 10000 11111],
    'F' => %w[11111 10000 11110 10000 10000 10000 10000],
    'G' => %w[01110 10001 10000 10111 10001 10001 01111],
    'H' => %w[10001 10001 11111 10001 10001 10001 10001],
    'I' => %w[01110 00100 00100 00100 00100 00100 01110],
    'L' => %w[10000 10000 10000 10000 10000 10000 11111],
    'M' => %w[10001 11011 10101 10101 10001 10001 10001],
    'N' => %w[10001 11001 10101 10011 10001 10001 10001],
    'O' => %w[01110 10001 10001 10001 10001 10001 01110],
    'P' => %w[11110 10001 10001 11110 10000 10000 10000],
    'R' => %w[11110 10001 10001 11110 10100 10010 10001],
    'S' => %w[01111 10000 10000 01110 00001 00001 11110],
    'T' => %w[11111 00100 00100 00100 00100 00100 00100],
    'U' => %w[10001 10001 10001 10001 10001 10001 01110],
    'V' => %w[10001 10001 10001 10001 10001 01010 00100],
    'W' => %w[10001 10001 10001 10101 10101 11011 10001],
    'Y' => %w[10001 10001 01010 00100 00100 00100 00100]
  }.freeze

  def self.color_of(c)
    case c
    when nil then [255, 255, 255, 1.0]
    when Array then [(c[0] * 255).to_i, (c[1] * 255).to_i, (c[2] * 255).to_i, c[3] || 1.0]
    when String
      if c.start_with?('#')
        [c[1, 2].to_i(16), c[3, 2].to_i(16), c[5, 2].to_i(16), 1.0]
      else
        rgb = COLORS[c.downcase] || [255, 255, 255]
        [rgb[0], rgb[1], rgb[2], 1.0]
      end
    else [255, 255, 255, 1.0]
    end
  end

  class Shape
    attr_accessor :x, :y, :z, :color
    def initialize(x: 0, y: 0, z: 0, color: nil, **_rest)
      @x = x; @y = y; @z = z; @color = color
      add
    end
    def add
      Window.shapes << self unless Window.shapes.include?(self)
      self
    end
    def remove
      Window.shapes.delete(self)
      self
    end
  end

  class Rectangle < Shape
    attr_accessor :width, :height
    def initialize(width: 0, height: 0, **rest)
      @width = width; @height = height
      super(**rest)
    end
    def draw(fb, w, h)
      r, g, b, a = Ruby2D.color_of(@color)
      Window.fill_rect(fb, w, h, @x.to_i, @y.to_i, @width.to_i, @height.to_i, r, g, b, a)
    end
  end

  class Square < Rectangle
    def initialize(size: 0, **rest)
      super(width: size, height: size, **rest)
    end
    def size = @width
  end

  module Font
    def self.path(name) = name
  end

  class Text < Shape
    attr_accessor :text, :size
    def initialize(text = '', size: 12, **rest)
      @text = text.to_s
      @size = size
      super(**rest)
    end
    def text=(v)
      @text = v.to_s
    end
    def scale = [(@size / 8), 1].max
    def width = @text.to_s.length * FONT_W * scale
    def height = FONT_H * scale
    def draw(fb, w, h)
      r, g, b, a = Ruby2D.color_of(@color || 'white')
      s = scale
      @text.to_s.each_char.with_index do |ch, i|
        rows = GLYPHS[ch] || GLYPHS[ch.upcase] || GLYPHS[' ']
        rows.each_with_index do |row, ry|
          row.each_char.with_index do |bit, rx|
            next if bit == '0'
            Window.fill_rect(fb, w, h, @x.to_i + (i * FONT_W + rx) * s, @y.to_i + ry * s,
                             s, s, r, g, b, a)
          end
        end
      end
    end
  end

  module Window
    @width = 640
    @height = 480
    @shapes = []
    @update = nil
    @handlers = {}
    @frames = 0
    @keys = {}

    class << self
      attr_reader :shapes, :handlers
      attr_accessor :width, :height, :title

      attr_accessor :shown
      def frames = @frames
      def set(opts = {})
        @width = opts[:width] if opts[:width]
        @height = opts[:height] if opts[:height]
        @title = opts[:title] if opts[:title]
      end
      def update(&block) = @update = block
      def on(event, &block) = (@handlers[event] ||= []) << block
      def run_update = @update&.call
      def frame_done = @frames += 1

      def fill_rect(fb, w, h, x, y, rw, rh, r, g, b, a)
        y0 = y < 0 ? 0 : y
        x0 = x < 0 ? 0 : x
        y1 = y + rh; y1 = h if y1 > h
        x1 = x + rw; x1 = w if x1 > w
        yy = y0
        while yy < y1
          base = (yy * w + x0) * 3
          xx = x0
          while xx < x1
            if a >= 1.0
              fb[base] = r; fb[base + 1] = g; fb[base + 2] = b
            else
              fb[base]     = (fb[base]     * (1 - a) + r * a).to_i
              fb[base + 1] = (fb[base + 1] * (1 - a) + g * a).to_i
              fb[base + 2] = (fb[base + 2] * (1 - a) + b * a).to_i
            end
            base += 3
            xx += 1
          end
          yy += 1
        end
      end

      # Draw every shape in z order into an RGB byte array.
      def render(fb)
        i = 0
        n = @width * @height * 3
        while i < n
          fb[i] = 0; fb[i + 1] = 0; fb[i + 2] = 0
          i += 3
        end
        @shapes.sort_by { |s| s.z.to_i }.each { |s| s.draw(fb, @width, @height) }
        fb
      end
    end
  end
end

# Ruby2D exposes everything at the top level.
include Ruby2D
def set(**opts) = Ruby2D::Window.set(opts)

# The game calls this last to hand control to the window; here the host owns
# the loop, so it only marks that setup is finished.
def show
  Ruby2D::Window.shown = true
end

class KeyEvent
  attr_reader :key
  def initialize(key) = @key = key
end

# rbtris uses a Mutex to keep its timer thread and the render loop apart; here
# there is one thread and the host drives the frames, so a no-op will do.
unless defined?(Mutex)
  class Mutex
    def synchronize = yield
  end
end

# The high score lives in ~/.rbtris.  wasm has no HOME and no writable home, so
# point it somewhere harmless; the file simply never exists.
class Dir
  def self.home = "/nonexistent"
end

field = nil
block_size = 30 + 2 * margin = 1
reset_field = lambda do
  text_highscore = Text.new("", x: 5, y: 5, z: 1, font: Font.path("PressStart2P-Regular.ttf"))
  lambda do
    field = Array.new(20){ Array.new 10 }
    text_highscore.text = "Highscore: #{
      File.exist?("#{Dir.home}/.rbtris") ?
        File.read("#{Dir.home}/.rbtris").scan(/^1 .*?(\S+)$/).map(&:first).map(&:to_i).max : "---"
    }"
  end
end.call
render = lambda do
  reset_field.call
  w = block_size * (2 + field.first.size)
  h = block_size * (3 + field.size)
  set width: w, height: h, title: "rbTris"
  Rectangle.new width: w,                  height: h,                  color: "gray"
  Rectangle.new width: w - 2 * block_size, height: h - 3 * block_size, color: "black", x: block_size, y: block_size * 2
  blocks = Array.new(field.size) do |y|
    Array.new(field.first.size) do |x|
      [ Square.new(x: margin + block_size * (1 + x),
                   y: margin + block_size * (2 + y),
                   size: block_size - 2 * margin) ]
    end
  end
  lambda do
    blocks.each_with_index do |row, i|
      row.each_with_index do |(block, drawn), j|
        if field[i][j]
          unless drawn == true
            block.color = %w{ aqua yellow green red blue orange purple }[(field[i][j] || 0) - 1]
            block.add
            row[j][1] = true
          end
        else
          unless drawn == false
            block.remove
            row[j][1] = false
          end
        end
      end
    end
  end
end.call

figure = x = y = nil
mix = lambda do |f|     # add or subtract the figure from the field (call it before rendering)
  figure.each_with_index do |row, dy|
    row.each_index do |dx|
      field[y + dy][x + dx] = (row[dx] if f) unless row[dx].zero?
    end
  end
end

collision = lambda do
  figure.each_with_index.any? do |row, dy|
    row.each_with_index.any? do |a, dx|
      not a.zero? ||
        ((0...field.size      ) === y + dy) &&
        ((0...field.first.size) === x + dx) &&
        !field[y + dy][x + dx]
    end
  end or (
    mix.call true
    render.call
    mix.call false
    false
  )
end

score = nil
text_score = Text.new score, x: 5, y: block_size + 5, z: 1, font: Font.path("PressStart2P-Regular.ttf")
text_level = Text.new score, x: 5, y: block_size + 5, z: 1, font: Font.path("PressStart2P-Regular.ttf")

paused = false
pause_rect = Rectangle.new(width: Window.width, height: Window.height, color: [0.5, 0.5, 0.5, 0.75]).tap &:remove
pause_text = Text.new("press 'Space'", z: 1, font: Font.path("PressStart2P-Regular.ttf")).tap &:remove
init_figure = lambda do
  figure = %w{ 070 777 006 666 500 555 440 044 033 330 22 22 1111 }.each_slice(2).to_a.sample
  rest = figure.first.size - figure.size
  x, y, figure = 3, 0, (
    [?0 * figure.first.size] * (rest / 2) + figure +
    [?0 * figure.first.size] * (rest - rest / 2)
  ).map{ |st| st.chars.map &:to_i }
  next unless collision.call
  File.open("#{Dir.home}/.rbtris", "a") do |f|
    f.puts "1 #{"#{text_level.text}   #{text_score.text}".tap &method(:puts)}"
  end
  [pause_rect, pause_text].each &((paused ^= true) ? :add : :remove)
  score = nil
end
reset = lambda do
  score, figure = 0, nil
  reset_field.call
  init_figure.call
end


semaphore = Mutex.new

prev, row_time = nil, 0
tap do
  reset.call
  Window.update do
    current = Time.now
    unless paused
      text_score.text = "Score: #{score}"
      text_score.x = Window.width - 5 - text_score.width
    end
    semaphore.synchronize do
      unless paused
        level = (((score / 5 + 0.125) * 2) ** 0.5 - 0.5 + 1e-6).floor  # outside of Mutex score is being accesses by render[]
        text_level.text = "Level: #{level}"
        row_time = (0.8 - (level - 1) * 0.007) ** (level - 1)
      end
      prev ||= current - row_time
      next unless current >= prev + row_time
      prev += row_time
      next unless figure && !paused
      y += 1
      next unless collision.call
      y -= 1
      # puts "FPS: #{(Window.frames.round - 1) / (current - first_time)}" if Window.frames.round > 1
      mix.call true
      field.partition(&:all?).tap do |a, b|
        field = a.map{ Array.new field.first.size } + b
        score += [0, 1, 3, 5, 8].fetch a.size
      end
      render.call
      init_figure.call
    end
  end
end


try_move = lambda do |dir|
  x += dir
  next unless collision.call
  x -= dir
end
try_rotate = lambda do
  figure = figure.reverse.transpose
  next unless collision.call
  figure = figure.transpose.reverse
end

holding = Hash.new
pause_text.x = (Window.width - pause_text.width) / 2
pause_text.y = (Window.height - pause_text.height) / 2
Window.on :key_down do |event|
  holding[event.key] = Time.now
  semaphore.synchronize do
    case event.key
    when "left"  ; try_move.call -1 if figure && !paused
    when "right" ; try_move.call +1 if figure && !paused
    when "up"    ; try_rotate.call  if figure && !paused
    when "r"
      reset.call unless paused
    when "p", "space"
      [pause_rect, pause_text].each &((paused ^= true) ? :add : :remove)
      reset.call unless score
    end
  end
end
Window.on :key_held do |event|
  semaphore.synchronize do
    case event.key
    when "left"  ; try_move.call -1 if figure && 0.5 < Time.now - holding[event.key]
    when "right" ; try_move.call +1 if figure && 0.5 < Time.now - holding[event.key]
    when "up"    ; try_rotate.call  if figure && 0.5 < Time.now - holding[event.key]
    when "down"
      y += 1
      prev = if collision.call
        y -= 1
        Time.now - row_time
      else
        Time.now
      end
    end
  end unless paused
end

show

# --- interactive driver ------------------------------------------------------
# Protocol: one byte in / one frame out.
#   in   bit 0 left, 1 right, 2 up, 3 down, 4 space, 5 r, 0xff = quit
#   out  Window.width * Window.height * 3 bytes, RGB
KEYS = ['left', 'right', 'up', 'down', 'space', 'r'].freeze
W = Ruby2D::Window.width
H = Ruby2D::Window.height
fb = Array.new(W * H * 3, 0)

$stdout.write("PAL0")
$stdout.write(([0] * 768).pack("C*"))

held = 0
loop do
  b = STDIN.read(1)
  break if b.nil?
  v = b.unpack1("C")
  break if v == 0xff

  KEYS.each_with_index do |name, i|
    now = (v >> i) & 1
    was = (held >> i) & 1
    ev = KeyEvent.new(name)
    if now == 1 && was == 0
      (Ruby2D::Window.handlers[:key_down] || []).each { |h| h.call(ev) }
    elsif now == 1
      (Ruby2D::Window.handlers[:key_held] || []).each { |h| h.call(ev) }
    elsif was == 1
      (Ruby2D::Window.handlers[:key_up] || []).each { |h| h.call(ev) }
    end
  end
  held = v

  Ruby2D::Window.run_update
  Ruby2D::Window.frame_done
  Ruby2D::Window.render(fb)
  $stdout.write(fb.pack("C*"))
  $stdout.flush
end
