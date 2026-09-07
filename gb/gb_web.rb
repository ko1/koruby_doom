unless File.respond_to?(:binread)
  class File
    def self.binread(path) = __binread(path)
    def self.read(path) = __binread(path)
  end
end
# frozen_string_literal: true

module Rubyboy
  VERSION = '1.5.1'
end

# frozen_string_literal: true

module Rubyboy
  class Interrupt
    INTERRUPTS = {
      vblank: 0,
      lcd: 1,
      timer: 2,
      serial: 3,
      joypad: 4
    }.freeze

    def initialize
      @ie = 0
      @if = 0
    end

    def read_byte(addr)
      case addr
      when 0xff0f
        @if
      when 0xffff
        @ie
      end
    end

    def write_byte(addr, value)
      case addr
      when 0xff0f
        @if = value
      when 0xffff
        @ie = value
      end
    end

    def interrupts
      @if & @ie & 0x1f
    end

    def request(interrupt)
      @if |= (1 << INTERRUPTS[interrupt])
    end

    def reset_flag(i)
      @if &= (~(1 << i)) & 0xff
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  class Ram
    attr_accessor :eram, :wram1, :wram2, :hram

    def initialize
      @eram = Array.new(0x2000, 0)
      @wram1 = Array.new(0x1000, 0)
      @wram2 = Array.new(0x1000, 0)
      @hram = Array.new(0x80, 0)
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  class Rom
    attr_reader :data, :entroy_point, :logo, :title, :new_licensee_code, :sgb_flag, :cartridge_type, :rom_size, :ram_size, :destination_code, :old_licensee_code, :mask_rom_version_number, :header_checksum, :global_checksum

    LOGO_DUMP = %w[
      CE ED 66 66 CC 0D 00 0B 03 73 00 83 00 0C 00 0D
      00 08 11 1F 88 89 00 0E DC CC 6E E6 DD DD D9 99
      BB BB 67 63 6E 0E EC CC DD DC 99 9F BB B9 33 3E
    ].map(&:hex).freeze

    def initialize(data)
      @data = data
      load_data
    end

    private

    def load_data
      @entroy_point = @data[0x100..0x103]
      @logo = @data[0x104..0x133]
      raise 'logo is not match' unless @logo == LOGO_DUMP

      @title = @data[0x134..0x143]
      @new_licensee_code = @data[0x144..0x145]
      @sgb_flag = @data[0x146]
      @cartridge_type = @data[0x147]
      @rom_size = @data[0x148]
      @ram_size = @data[0x149]
      @destination_code = @data[0x14A]
      @old_licensee_code = @data[0x14B]
      @mask_rom_version_number = @data[0x14C]
      @header_checksum = @data[0x14D]
      @global_checksum = @data[0x14E..0x14F]
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  class Registers
    attr_reader :a, :b, :c, :d, :e, :h, :l, :f

    def initialize
      @a = 0x01
      @b = 0x00
      @c = 0x13
      @d = 0x00
      @e = 0xd8
      @h = 0x01
      @l = 0x4d
      @f = 0xb0
    end

    def a=(value)
      @a = value & 0xff
    end

    def b=(value)
      @b = value & 0xff
    end

    def c=(value)
      @c = value & 0xff
    end

    def d=(value)
      @d = value & 0xff
    end

    def e=(value)
      @e = value & 0xff
    end

    def h=(value)
      @h = value & 0xff
    end

    def l=(value)
      @l = value & 0xff
    end

    def f=(value)
      @f = value & 0xf0
    end

    def af
      (@a << 8) | @f
    end

    def bc
      (@b << 8) | @c
    end

    def de
      (@d << 8) | @e
    end

    def hl
      (@h << 8) | @l
    end

    def af=(value)
      @a = (value >> 8) & 0xff
      @f = value & 0xf0
    end

    def bc=(value)
      @b = (value >> 8) & 0xff
      @c = value & 0xff
    end

    def de=(value)
      @d = (value >> 8) & 0xff
      @e = value & 0xff
    end

    def hl=(value)
      @h = (value >> 8) & 0xff
      @l = value & 0xff
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  class Timer
    def initialize(interrupt)
      @div = 0
      @tima = 0
      @tma = 0
      @tac = 0
      @cycles = 0
      @interrupt = interrupt
    end

    def step(cycles)
      before_cycles = @cycles
      after_cycles = @cycles + cycles
      @cycles = after_cycles & 0xffff

      @div += after_cycles / 256 - before_cycles / 256
      @div &= 0xffff

      return if @tac[2] == 0

      divider = case @tac & 0b11
                when 0b00 then 1024
                when 0b01 then 16
                when 0b10 then 64
                when 0b11 then 256
                end

      tima_diff = (after_cycles / divider - before_cycles / divider)
      @tima += tima_diff

      return if @tima < 256

      @tima = @tma
      @interrupt.request(:timer)
    end

    def read_byte(byte)
      case byte
      when 0xff04
        @div >> 8
      when 0xff05
        @tima
      when 0xff06
        @tma
      when 0xff07
        @tac | 0b1111_1000
      end
    end

    def write_byte(byte, value)
      case byte
      when 0xff04
        @div = 0
        @cycles = 0
      when 0xff05
        @tima = value
      when 0xff06
        @tma = value
      when 0xff07
        @tac = value & 0b111
      end
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  class Joypad
    def initialize(interupt)
      @mode = 0xcf
      @action = 0xff
      @direction = 0xff
      @interupt = interupt
    end

    def read_byte(addr)
      raise "not implemented: write_byte #{addr}" unless addr == 0xff00

      res = @mode | 0xcf
      res &= @direction if @mode[4] == 0
      res &= @action if @mode[5] == 0

      res
    end

    def write_byte(addr, value)
      raise "not implemented: write_byte #{addr}" unless addr == 0xff00

      @mode = value & 0x30
      @mode |= 0xc0
    end

    def direction_button(button)
      @direction = button | 0xf0

      @interupt.request(:joypad) if button < 0b1111
    end

    def action_button(button)
      @action = button | 0xf0

      @interupt.request(:joypad) if button < 0b1111
    end
  end
end

# frozen_string_literal: true


module Rubyboy
  class Lcd
    SCREEN_WIDTH = 160
    SCREEN_HEIGHT = 144
    SCALE = 3

    def initialize
      raise SDL.GetError() if SDL.InitSubSystem(SDL::INIT_VIDEO) != 0

      @buffer = FFI::MemoryPointer.new(:uint32, SCREEN_WIDTH * SCREEN_HEIGHT)
      @window = SDL.CreateWindow('Ruby Boy', 0, 0, SCREEN_WIDTH * SCALE, SCREEN_HEIGHT * SCALE, SDL::SDL_WINDOW_RESIZABLE)

      raise SDL.GetError() if @window.null?

      @renderer = SDL.CreateRenderer(@window, -1, 0)
      SDL.SetHint('SDL_HINT_RENDER_SCALE_QUALITY', '2')
      SDL.RenderSetLogicalSize(@renderer, SCREEN_WIDTH * SCALE, SCREEN_HEIGHT * SCALE)
      @texture = SDL.CreateTexture(@renderer, SDL::PIXELFORMAT_ABGR8888, 1, SCREEN_WIDTH, SCREEN_HEIGHT)
      @event = FFI::MemoryPointer.new(:pointer)
    end

    def draw(framebuffer)
      @buffer.write_array_of_uint32(framebuffer)
      SDL.UpdateTexture(@texture, nil, @buffer, SCREEN_WIDTH * 4)
      SDL.RenderClear(@renderer)
      SDL.RenderCopy(@renderer, @texture, nil, nil)
      SDL.RenderPresent(@renderer)
    end

    def window_should_close?
      while SDL.PollEvent(@event) != 0
        event_type = @event.read_int
        return true if event_type == SDL::QUIT
      end

      false
    end

    def close_window
      SDL.DestroyWindow(@window)
      SDL.Quit
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  class Ppu
    attr_reader :buffer

    MODE = {
      hblank: 0,
      vblank: 1,
      oam_scan: 2,
      drawing: 3
    }.freeze

    LCDC = {
      bg_window_enable: 0,
      sprite_enable: 1,
      sprite_size: 2,
      bg_tile_map_area: 3,
      bg_window_tile_data_area: 4,
      window_enable: 5,
      window_tile_map_area: 6,
      lcd_ppu_enable: 7
    }.freeze

    STAT = {
      ly_eq_lyc: 2,
      hblank: 3,
      vblank: 4,
      oam_scan: 5,
      lyc: 6
    }.freeze

    SPRITE_FLAGS = {
      bank: 3,
      dmg_palette: 4,
      x_flip: 5,
      y_flip: 6,
      priority: 7
    }.freeze

    LCD_WIDTH = 160
    LCD_HEIGHT = 144

    OAM_SCAN_CYCLES = 80
    DRAWING_CYCLES = 172
    HBLANK_CYCLES = 204
    ONE_LINE_CYCLES = OAM_SCAN_CYCLES + DRAWING_CYCLES + HBLANK_CYCLES

    def initialize(interrupt)
      @mode = MODE[:oam_scan]
      @lcdc = 0x91
      @stat = 0x00
      @scy = 0x00
      @scx = 0x00
      @ly = 0x00
      @lyc = 0x00
      @obp0 = 0x00
      @obp1 = 0x00
      @wy = 0x00
      @wx = 0x00
      @bgp = 0x00
      @vram = Array.new(0x2000, 0x00)
      @oam = Array.new(0xa0, 0x00)
      @wly = 0x00
      @cycles = 0
      @interrupt = interrupt
      @buffer = Array.new(144 * 160, 0xffffffff)
      @bg_pixels = Array.new(LCD_WIDTH, 0x00)
      @tile_cache = Array.new(384) { Array.new(64, 0) }
      @tile_map_cache = Array.new(2048, 0)
      @bgp_cache = Array.new(4, 0xffffffff)
      @obp0_cache = Array.new(4, 0xffffffff)
      @obp1_cache = Array.new(4, 0xffffffff)
      @sprite_cache = Array.new(40) { { y: 0xff, x: 0xff, tile_index: 0, flags: 0 } }
    end

    def read_byte(addr)
      case addr
      when 0x8000..0x9fff
        @mode == MODE[:drawing] ? 0xff : @vram[addr - 0x8000]
      when 0xfe00..0xfe9f
        @mode == MODE[:oam_scan] || @mode == MODE[:drawing] ? 0xff : @oam[addr - 0xfe00]
      when 0xff40
        @lcdc
      when 0xff41
        @stat | 0x80 | @mode
      when 0xff42
        @scy
      when 0xff43
        @scx
      when 0xff44
        @ly
      when 0xff45
        @lyc
      when 0xff47
        @bgp
      when 0xff48
        @obp0
      when 0xff49
        @obp1
      when 0xff4a
        @wy
      when 0xff4b
        @wx
      end
    end

    def write_byte(addr, value)
      case addr
      when 0x8000..0x9fff
        if @mode != MODE[:drawing]
          @vram[addr - 0x8000] = value
          if addr < 0x9800
            update_tile_cache(addr - 0x8000)
          else
            update_tile_map_cache(addr - 0x8000)
          end
        end
      when 0xfe00..0xfe9f
        if @mode != MODE[:oam_scan] && @mode != MODE[:drawing]
          @oam[addr - 0xfe00] = value
          sprite_index = (addr - 0xfe00) >> 2
          attribute = (addr - 0xfe00) & 3

          case attribute
          when 0 then @sprite_cache[sprite_index][:y] = (value - 16) & 0xff
          when 1 then @sprite_cache[sprite_index][:x] = (value - 8) & 0xff
          when 2 then @sprite_cache[sprite_index][:tile_index] = value
          when 3 then @sprite_cache[sprite_index][:flags] = value
          end
        end
      when 0xff40
        old_lcdc = @lcdc
        @lcdc = value

        refresh_tile_map_cache if old_lcdc[LCDC[:bg_window_tile_data_area]] != value[LCDC[:bg_window_tile_data_area]]
      when 0xff41
        @stat = value & 0x78
      when 0xff42
        @scy = value
      when 0xff43
        @scx = value
      when 0xff44
        # ly is read only
      when 0xff45
        @lyc = value
      when 0xff47
        @bgp = value
        refresh_palette_cache(@bgp_cache, value)
      when 0xff48
        @obp0 = value
        refresh_palette_cache(@obp0_cache, value)
      when 0xff49
        @obp1 = value
        refresh_palette_cache(@obp1_cache, value)
      when 0xff4a
        @wy = value
      when 0xff4b
        @wx = value
      end
    end

    def step(cycles)
      return false if @lcdc[LCDC[:lcd_ppu_enable]] == 0

      res = false
      @cycles += cycles

      case @mode
      when MODE[:oam_scan]
        if @cycles >= OAM_SCAN_CYCLES
          @cycles -= OAM_SCAN_CYCLES
          @mode = MODE[:drawing]
        end
      when MODE[:drawing]
        if @cycles >= DRAWING_CYCLES
          render_bg
          render_window
          render_sprites
          @cycles -= DRAWING_CYCLES
          @mode = MODE[:hblank]
          @interrupt.request(:lcd) if @stat[STAT[:hblank]] == 1
        end
      when MODE[:hblank]
        if @cycles >= HBLANK_CYCLES
          @cycles -= HBLANK_CYCLES
          @ly += 1
          handle_ly_eq_lyc

          if @ly == LCD_HEIGHT
            @mode = MODE[:vblank]
            @interrupt.request(:vblank)
            @interrupt.request(:lcd) if @stat[STAT[:vblank]] == 1
          else
            @mode = MODE[:oam_scan]
            @interrupt.request(:lcd) if @stat[STAT[:oam_scan]] == 1
          end
        end
      when MODE[:vblank]
        if @cycles >= ONE_LINE_CYCLES
          @cycles -= ONE_LINE_CYCLES
          @ly += 1
          handle_ly_eq_lyc

          if @ly == 154
            @ly = 0
            @wly = 0
            handle_ly_eq_lyc
            @mode = MODE[:oam_scan]
            @interrupt.request(:lcd) if @stat[STAT[:oam_scan]] == 1
            res = true
          end
        end
      end

      res
    end

    def render_bg
      return if @lcdc[LCDC[:bg_window_enable]] == 0

      y = (@ly + @scy) & 0xff
      tile_map_addr = (y >> 3) << 5
      tile_map_addr += 1024 if @lcdc[LCDC[:bg_tile_map_area]] == 1
      tile_y = (y & 7) << 3
      buffer_start_index = @ly * LCD_WIDTH

      scx = @scx
      buffer = @buffer
      bg_pixels = @bg_pixels
      tile_cache = @tile_cache
      tile_map_cache = @tile_map_cache
      bgp_cache = @bgp_cache

      i = 0
      current_tile = scx >> 3
      x_offset = scx & 7

      if x_offset > 0
        tile = tile_cache[tile_map_cache[tile_map_addr + current_tile]]
        while (x_offset + i) < 8
          pixel = tile[tile_y + x_offset + i]
          buffer[buffer_start_index + i] = bgp_cache[pixel]
          bg_pixels[i] = pixel
          i += 1
        end
        current_tile += 1
      end

      while i < LCD_WIDTH - 7
        tile = tile_cache[tile_map_cache[tile_map_addr + (current_tile & 0x1f)]]
        idx = buffer_start_index + i

        # Unroll the 8-pixel loop
        pixel = tile[tile_y]
        buffer[idx] = bgp_cache[pixel]
        bg_pixels[i] = pixel

        pixel = tile[tile_y + 1]
        buffer[idx + 1] = bgp_cache[pixel]
        bg_pixels[i + 1] = pixel

        pixel = tile[tile_y + 2]
        buffer[idx + 2] = bgp_cache[pixel]
        bg_pixels[i + 2] = pixel

        pixel = tile[tile_y + 3]
        buffer[idx + 3] = bgp_cache[pixel]
        bg_pixels[i + 3] = pixel

        pixel = tile[tile_y + 4]
        buffer[idx + 4] = bgp_cache[pixel]
        bg_pixels[i + 4] = pixel

        pixel = tile[tile_y + 5]
        buffer[idx + 5] = bgp_cache[pixel]
        bg_pixels[i + 5] = pixel

        pixel = tile[tile_y + 6]
        buffer[idx + 6] = bgp_cache[pixel]
        bg_pixels[i + 6] = pixel

        pixel = tile[tile_y + 7]
        buffer[idx + 7] = bgp_cache[pixel]
        bg_pixels[i + 7] = pixel

        i += 8
        current_tile += 1
      end

      return unless i < LCD_WIDTH

      tile = tile_cache[tile_map_cache[tile_map_addr + (current_tile & 0x1f)]]
      x = 0
      while i < LCD_WIDTH
        pixel = tile[tile_y + x]
        buffer[buffer_start_index + i] = bgp_cache[pixel]
        bg_pixels[i] = pixel
        x += 1
        i += 1
      end
    end

    def render_window
      return if @lcdc[LCDC[:bg_window_enable]] == 0 || @lcdc[LCDC[:window_enable]] == 0 || @ly < @wy

      rendered = false
      y = @wly
      tile_map_addr = (y >> 3) << 5
      tile_map_addr += 1024 if @lcdc[LCDC[:window_tile_map_area]] == 1
      tile_y = (y & 7) << 3
      buffer_start_index = @ly * LCD_WIDTH
      LCD_WIDTH.times do |i|
        next if i < @wx - 7

        rendered = true
        x = i - (@wx - 7)
        tile_index = @tile_map_cache[tile_map_addr + (x >> 3)]
        pixel = @tile_cache[tile_index][tile_y + (x & 7)]
        @buffer[buffer_start_index + i] = @bgp_cache[pixel]
        @bg_pixels[i] = pixel
      end
      @wly += 1 if rendered
    end

    def render_sprites
      return if @lcdc[LCDC[:sprite_enable]] == 0

      sprite_height = @lcdc[LCDC[:sprite_size]] == 0 ? 8 : 16
      sprites = []
      cnt = 0

      @sprite_cache.each do |sprite|
        next if sprite[:y] > @ly || sprite[:y] + sprite_height <= @ly

        sprites << sprite
        cnt += 1
        break if cnt == 10
      end
      sprites.reverse!
      sprites.sort! { |a, b| b[:x] <=> a[:x] }

      sprites.each do |sprite|
        flags = sprite[:flags]
        pallet = flags[SPRITE_FLAGS[:dmg_palette]] == 0 ? @obp0_cache : @obp1_cache
        tile_index = sprite[:tile_index]
        tile_index &= 0xfe if sprite_height == 16
        y = (@ly - sprite[:y]) & 0xff
        y = sprite_height - y - 1 if flags[SPRITE_FLAGS[:y_flip]] == 1
        tile_index = (tile_index + 1) & 0xff if y >= 8
        tile_y = (y & 7) << 3
        buffer_start_index = @ly * LCD_WIDTH

        8.times do |x|
          x_flipped = flags[SPRITE_FLAGS[:x_flip]] == 1 ? 7 - x : x

          pixel = @tile_cache[tile_index][tile_y + x_flipped]
          i = (sprite[:x] + x) & 0xff

          next if pixel == 0 || i >= LCD_WIDTH
          next if flags[SPRITE_FLAGS[:priority]] == 1 && @bg_pixels[i] != 0

          @buffer[buffer_start_index + i] = pallet[pixel]
        end
      end
    end

    private

    def update_tile_cache(addr)
      tile_index = addr >> 4
      row = ((addr & 0xf) >> 1) << 3

      byte1 = @vram[addr & ~1]
      byte2 = @vram[addr | 1]

      8.times do |col|
        bit_index = 7 - col
        pixel = ((byte1 >> bit_index) & 1) | (((byte2 >> bit_index) & 1) << 1)
        @tile_cache[tile_index][row + col] = pixel
      end
    end

    def update_tile_map_cache(addr)
      map_index = addr - 0x1800
      tile_index = @vram[addr]
      @tile_map_cache[map_index] = @lcdc[LCDC[:bg_window_tile_data_area]] == 0 ? to_signed_byte(tile_index) + 256 : tile_index
    end

    def refresh_tile_map_cache
      if @lcdc[LCDC[:bg_window_tile_data_area]] == 0
        (0x1800..0x1fff).each do |addr|
          @tile_map_cache[addr - 0x1800] = to_signed_byte(@vram[addr]) + 256
        end
      else
        (0x1800..0x1fff).each do |addr|
          @tile_map_cache[addr - 0x1800] = @vram[addr]
        end
      end
    end

    def refresh_palette_cache(cache, palette_value)
      4.times do |i|
        case (palette_value >> (i << 1)) & 0b11
        when 0 then cache[i] = 0xffffffff
        when 1 then cache[i] = 0xffaaaaaa
        when 2 then cache[i] = 0xff555555
        when 3 then cache[i] = 0xff000000
        end
      end
    end

    def to_signed_byte(byte)
      byte &= 0xff
      byte > 127 ? byte - 256 : byte
    end

    def handle_ly_eq_lyc
      if @ly == @lyc
        @stat |= 0x04
        @interrupt.request(:lcd) if @stat[STAT[:lyc]] == 1
      else
        @stat &= 0xfb
      end
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  module ApuChannels
    class Channel1
      attr_accessor :enabled, :wave_duty_position

      WAVE_DUTY = [
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0], # 12.5%
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0], # 25%
        [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0], # 50%
        [0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]  # 75%
      ].freeze

      def initialize
        @cycles = 0
        @frequency = 0
        @frequency_timer = 0
        @wave_duty_position = 0

        @enabled = false
        @dac_enabled = false
        @length_enabled = false
        @is_upwards = false
        @is_decrementing = false
        @sweep_enabled = false
        @sweep_period = 0
        @sweep_shift = 0
        @period = 0
        @period_timer = 0
        @current_volume = 0
        @initial_volume = 0
        @shadow_frequency = 0
        @sweep_timer = 0
        @length_timer = 0
        @wave_duty_pattern = 0
      end

      def step(cycles)
        @cycles += cycles

        return if @cycles < @frequency_timer

        @cycles -= @frequency_timer
        @frequency_timer = (2048 - @frequency) * 4
        @wave_duty_position = (@wave_duty_position + 1) % 8
      end

      def step_fs(fs)
        length if fs & 0x01 == 0
        envelope if fs == 7
        sweep if fs == 2 || fs == 6
      end

      def length
        return unless @length_enabled && @length_timer > 0

        @length_timer -= 1
        @enabled &= @length_timer > 0
      end

      def envelope
        return if @period == 0

        @period_timer -= 1 if @period_timer > 0

        return if @period_timer != 0

        @period_timer = @period

        if @current_volume < 15 && @is_upwards
          @current_volume += 1
        elsif @current_volume > 0 && !@is_upwards
          @current_volume -= 1
        end
      end

      def sweep
        @sweep_timer -= 1 if @sweep_timer > 0

        return if @sweep_timer != 0

        @sweep_timer = @sweep_period

        return unless @sweep_enabled

        @frequency = calculate_frequency
        @shadow_frequency = @frequency
      end

      def calculate_frequency
        if @is_decrementing
          if @shadow_frequency >= (@shadow_frequency >> @sweep_shift)
            @shadow_frequency - (@shadow_frequency >> @sweep_shift)
          else
            0
          end
        else
          [0x3ff, @shadow_frequency + (@shadow_frequency >> @sweep_shift)].min
        end
      end

      def dac_output
        return 0.0 unless @dac_enabled && @enabled

        ret = WAVE_DUTY[@wave_duty_pattern][@wave_duty_position] * @current_volume
        (ret / 7.5) - 1.0
      end

      def read_nr1x(x)
        case x
        when 0 then (@sweep_period << 4) | @sweep_shift | (@is_decrementing ? 0x08 : 0x00) | 0x80
        when 1 then (@wave_duty_pattern << 6) | 0x3f
        when 2 then (@initial_volume << 4) | (@is_upwards ? 0x08 : 0x00) | @period
        when 3 then 0xff
        when 4 then (@length_enabled ? 0x40 : 0x00) | 0xbf
        else 0xff
        end
      end

      def write_nr1x(x, val)
        case x
        when 0
          @sweep_period = (val >> 4) & 0x07
          @is_decrementing = (val & 0x08) > 0
          @sweep_shift = val & 0x07
        when 1
          @wave_duty_pattern = (val >> 6) & 0x03
          @length_timer = 64 - (val & 0x3f)
        when 2
          @is_upwards = (val & 0x08) > 0
          @initial_volume = (val >> 4)
          @period = val & 0x07
          @dac_enabled = val & 0xf8 > 0
          @enabled &= @dac_enabled
        when 3
          @frequency = (@frequency & 0x700) | val
        when 4
          @frequency = (@frequency & 0xff) | ((val & 0x07) << 8)
          @length_enabled = (val & 0x40) > 0
          @length_timer = 64 if @length_timer == 0
          return unless (val & 0x80) > 0 && @dac_enabled

          @enabled = true
          @period_timer = @period
          @current_volume = @initial_volume
          @shadow_frequency = @frequency
          @sweep_timer = @sweep_period
          @sweep_enabled = @sweep_period > 0 || @sweep_shift > 0
        end
      end
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  module ApuChannels
    class Channel2
      attr_accessor :enabled, :wave_duty_position

      WAVE_DUTY = [
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0], # 12.5%
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0], # 25%
        [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0], # 50%
        [0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]  # 75%
      ].freeze

      def initialize
        @cycles = 0
        @frequency = 0
        @frequency_timer = 0
        @wave_duty_position = 0

        @enabled = false
        @dac_enabled = false
        @length_enabled = false
        @is_upwards = false
        @is_decrementing = false
        @period = 0
        @period_timer = 0
        @current_volume = 0
        @initial_volume = 0
        @shadow_frequency = 0
        @length_timer = 0
        @wave_duty_pattern = 0
      end

      def step(cycles)
        @cycles += cycles

        return if @cycles < @frequency_timer

        @cycles -= @frequency_timer
        @frequency_timer = (2048 - @frequency) * 4
        @wave_duty_position = (@wave_duty_position + 1) % 8
      end

      def step_fs(fs)
        length if fs & 0x01 == 0
        envelope if fs == 7
      end

      def length
        return unless @length_enabled && @length_timer > 0

        @length_timer -= 1
        @enabled &= @length_timer > 0
      end

      def envelope
        return if @period == 0

        @period_timer -= 1 if @period_timer > 0

        return if @period_timer != 0

        @period_timer = @period

        if @current_volume < 15 && @is_upwards
          @current_volume += 1
        elsif @current_volume > 0 && !@is_upwards
          @current_volume -= 1
        end
      end

      def dac_output
        return 0.0 unless @dac_enabled && @enabled

        ret = WAVE_DUTY[@wave_duty_pattern][@wave_duty_position] * @current_volume
        (ret / 7.5) - 1.0
      end

      def read_nr2x(x)
        case x
        when 1 then (@wave_duty_pattern << 6) | 0x3f
        when 2 then (@initial_volume << 4) | (@is_upwards ? 0x08 : 0x00) | @period
        when 3 then 0xff
        when 4 then (@length_enabled ? 0x40 : 0x00) | 0xbf
        else 0xff
        end
      end

      def write_nr2x(x, val)
        case x
        when 1
          @wave_duty_pattern = (val >> 6) & 0x03
          @length_timer = 64 - (val & 0x3f)
        when 2
          @is_upwards = (val & 0x08) > 0
          @initial_volume = (val >> 4)
          @period = val & 0x07
          @dac_enabled = val & 0xf8 > 0
          @enabled &= @dac_enabled
        when 3
          @frequency = (@frequency & 0x700) | val
        when 4
          @frequency = (@frequency & 0xff) | ((val & 0x07) << 8)
          @length_enabled = (val & 0x40) > 0
          @length_timer = 64 if @length_timer == 0
          return unless (val & 0x80) > 0 && @dac_enabled

          @enabled = true
          @period_timer = @period
          @current_volume = @initial_volume
        end
      end
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  module ApuChannels
    class Channel3
      attr_accessor :enabled, :wave_duty_position, :wave_ram

      WAVE_DUTY = [
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0], # 12.5%
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0], # 25%
        [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0], # 50%
        [0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]  # 75%
      ].freeze

      def initialize
        @cycles = 0
        @frequency = 0
        @frequency_timer = 0
        @wave_duty_position = 0

        @enabled = false
        @dac_enabled = false
        @length_enabled = false
        @is_upwards = false
        @is_decrementing = false
        @sweep_enabled = false
        @sweep_period = 0
        @sweep_shift = 0
        @period = 0
        @period_timer = 0
        @current_volume = 0
        @initial_volume = 0
        @shadow_frequency = 0
        @sweep_timer = 0
        @length_timer = 0
        @wave_duty_pattern = 0

        @output_level = 0
        @volume_shift = 0
        @wave_ram = Array.new(16, 0)
      end

      def step(cycles)
        @cycles += cycles

        return if @cycles < @frequency_timer

        @cycles -= @frequency_timer
        @frequency_timer = (2048 - @frequency) * 2
        @wave_duty_position = (@wave_duty_position + 1) % 32
      end

      def step_fs(fs)
        length if fs & 0x01 == 0
      end

      def length
        return unless @length_enabled && @length_timer > 0

        @length_timer -= 1
        @enabled &= @length_timer > 0
      end

      def calculate_frequency
        if @is_decrementing
          if @shadow_frequency >= (@shadow_frequency >> @sweep_shift)
            @shadow_frequency - (@shadow_frequency >> @sweep_shift)
          else
            0
          end
        else
          [0x3ff, @shadow_frequency + (@shadow_frequency >> @sweep_shift)].min
        end
      end

      def dac_output
        return 0.0 unless @dac_enabled && @enabled

        ret = ((0xf & (
          @wave_ram[@wave_duty_position >> 1] >> ((@wave_duty_position & 0x01) << 2)
        ))) >> @volume_shift

        (ret / 7.5) - 1.0
      end

      def read_nr3x(x)
        case x
        when 0 then ((@dac_enabled ? 0x80 : 0x00) | 0x7f)
        when 1 then 0xff
        when 2 then (@output_level << 5) | 0x9f
        when 3 then 0xff
        when 4 then (@length_enabled ? 0x40 : 0x00) | 0xbf
        else 0xff
        end
      end

      def write_nr3x(x, val)
        case x
        when 0
          @dac_enabled = val & 0x80 > 0
          @enabled &= @dac_enabled
        when 1
          @length_timer = 256 - val
        when 2
          @output_level = (val >> 5) & 0x03
        when 3
          @frequency = (@frequency & 0x700) | val
        when 4
          @frequency = (@frequency & 0xff) | ((val & 0x07) << 8)
          @length_enabled = val & 0x40 > 0
          @length_timer = 256 if @length_timer == 0
          @enabled = true if (val & 0x80) > 0 && @dac_enabled
        end
      end
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  module ApuChannels
    class Channel4
      attr_accessor :enabled, :wave_duty_position

      WAVE_DUTY = [
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0], # 12.5%
        [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0], # 25%
        [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0], # 50%
        [0.0, 0.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]  # 75%
      ].freeze

      def initialize
        @cycles = 0
        @frequency = 0
        @frequency_timer = 0
        @wave_duty_position = 0

        @enabled = false
        @dac_enabled = false
        @length_enabled = false
        @is_upwards = false
        @is_decrementing = false
        @sweep_enabled = false
        @sweep_period = 0
        @sweep_shift = 0
        @period = 0
        @period_timer = 0
        @current_volume = 0
        @initial_volume = 0
        @shadow_frequency = 0
        @sweep_timer = 0
        @length_timer = 0
        @wave_duty_pattern = 0

        @lfsr = 0x7fff
        @width_mode = false
        @shift_amount = 0
        @divisor_code = 0
      end

      def step(cycles)
        @cycles += cycles

        return if @cycles < @frequency_timer

        @cycles -= @frequency_timer
        @frequency_timer = [8, @divisor_code << 4].max << @shift_amount

        xor = (@lfsr & 0x01) ^ ((@lfsr & 0b10) >> 1)
        @lfsr = (@lfsr >> 1) | (xor << 14)
        return unless @width_mode

        @lfsr &= ~(1 << 6)
        @lfsr |= xor << 6
      end

      def step_fs(fs)
        length if fs & 0x01 == 0
        envelope if fs == 7
      end

      def length
        return unless @length_enabled && @length_timer > 0

        @length_timer -= 1
        @enabled &= @length_timer > 0
      end

      def envelope
        return if @period == 0

        @period_timer -= 1 if @period_timer > 0

        return if @period_timer != 0

        @period_timer = @period

        if @current_volume < 15 && @is_upwards
          @current_volume += 1
        elsif @current_volume > 0 && !@is_upwards
          @current_volume -= 1
        end
      end

      def calculate_frequency
        if @is_decrementing
          if @shadow_frequency >= (@shadow_frequency >> @sweep_shift)
            @shadow_frequency - (@shadow_frequency >> @sweep_shift)
          else
            0
          end
        else
          [0x3ff, @shadow_frequency + (@shadow_frequency >> @sweep_shift)].min
        end
      end

      def dac_output
        return 0.0 unless @dac_enabled && @enabled

        ret = (@lfsr & 0x01) * @current_volume
        (ret / 7.5) - 1.0
      end

      def read_nr4x(x)
        case x
        when 0 then 0xff
        when 1 then 0xff
        when 2 then (@initial_volume << 4) | (@is_upwards ? 0x08 : 0x00) | @period
        when 3 then (@shift_amount << 4) | (@width_mode ? 0x08 : 0x00) | @divisor_code
        when 4 then (@length_enabled ? 0x40 : 0x00) | 0xbf
        else 0xff
        end
      end

      def write_nr4x(x, val)
        case x
        when 0
          # nop
        when 1
          @length_timer = 64 - (val & 0x3f)
        when 2
          @is_upwards = (val & 0x08) > 0
          @initial_volume = val >> 4
          @period = val & 0x07
          @dac_enabled = val & 0xf8 > 0
          @enabled &= @dac_enabled
        when 3
          @shift_amount = (val >> 4) & 0x0f
          @width_mode = (val & 0x08) > 0
          @divisor_code = val & 0x07
        when 4
          @length_enabled = (val & 0x40) > 0
          @length_timer = 64 if @length_timer == 0
          return unless (val & 0x80) > 0

          @enabled = true if @dac_enabled

          @lfsr = 0x7fff
          @period_timer = @period
          @current_volume = @initial_volume
        end
      end
    end
  end
end

# frozen_string_literal: true


module Rubyboy
  class Apu
    attr_reader :samples

    def initialize
      @nr50 = 0
      @nr51 = 0
      @cycles = 0
      @sampling_cycles = 0
      @fs = 0
      @samples = Array.new(1024, 0.0)
      @sample_idx = 0
      @channel1 = ApuChannels::Channel1.new
      @channel2 = ApuChannels::Channel2.new
      @channel3 = ApuChannels::Channel3.new
      @channel4 = ApuChannels::Channel4.new
    end

    def step(cycles)
      @cycles += cycles
      @sampling_cycles += cycles

      @channel1.step(cycles)
      @channel2.step(cycles)
      @channel3.step(cycles)
      @channel4.step(cycles)

      if @cycles >= 0x2000
        @cycles -= 0x2000

        @channel1.step_fs(@fs)
        @channel2.step_fs(@fs)
        @channel3.step_fs(@fs)
        @channel4.step_fs(@fs)

        @fs = (@fs + 1) % 8
      end

      if @sampling_cycles >= 87
        @sampling_cycles -= 87

        left_sample = (
          @nr51[7] * @channel4.dac_output +
          @nr51[6] * @channel3.dac_output +
          @nr51[5] * @channel2.dac_output +
          @nr51[4] * @channel1.dac_output
        ) / 4.0

        right_sample = (
          @nr51[3] * @channel4.dac_output +
          @nr51[2] * @channel3.dac_output +
          @nr51[1] * @channel2.dac_output +
          @nr51[0] * @channel1.dac_output
        ) / 4.0

        raise "#{@nr51} #{@channel4.dac_output}, #{@channel3.dac_output}, #{@channel2.dac_output},#{@channel1.dac_output}" if left_sample.abs > 1.0 || right_sample.abs > 1.0

        @samples[@sample_idx * 2] = (@nr50[4..6] / 7.0) * left_sample / 8.0
        @samples[@sample_idx * 2 + 1] = (@nr50[0..2] / 7.0) * right_sample / 8.0
        @sample_idx += 1
      end

      return false if @sample_idx < 512

      @sample_idx = 0
      true
    end

    def read_byte(addr)
      case addr
      when 0xff10..0xff14 then @channel1.read_nr1x(addr - 0xff10)
      when 0xff15..0xff19 then @channel2.read_nr2x(addr - 0xff15)
      when 0xff1a..0xff1e then @channel3.read_nr3x(addr - 0xff1a)
      when 0xff1f..0xff23 then @channel4.read_nr4x(addr - 0xff1f)
      when 0xff24 then @nr50
      when 0xff25 then @nr51
      when 0xff26 then (@channel1.enabled ? 0x01 : 0x00) | (@channel2.enabled ? 0x02 : 0x00) | (@channel3.enabled ? 0x04 : 0x00) | (@channel4.enabled ? 0x08 : 0x00) | 0x70 | (@enabled ? 0x80 : 0x00)
      when 0xff30..0xff3f then @channel3.wave_ram[(addr - 0xff30)]
      else raise "Invalid APU read at #{addr.to_s(16)}"
      end
    end

    def write_byte(addr, val)
      return if !@enabled && ![0xff11, 0xff16, 0xff1b, 0xff20, 0xff26].include?(addr) && !(0xff30..0xff3f).include?(addr)

      val &= 0x3f if !@enabled && [0xff11, 0xff16, 0xff1b, 0xff20].include?(addr)

      case addr
      when 0xff10..0xff14 then @channel1.write_nr1x(addr - 0xff10, val)
      when 0xff15..0xff19 then @channel2.write_nr2x(addr - 0xff15, val)
      when 0xff1a..0xff1e then @channel3.write_nr3x(addr - 0xff1a, val)
      when 0xff1f..0xff23 then @channel4.write_nr4x(addr - 0xff1f, val)
      when 0xff24 then @nr50 = val
      when 0xff25 then @nr51 = val
      when 0xff26
        flg = val & 0x80 > 0
        if !flg && @enabled
          (0xff10..0xff25).each { |a| write_byte(a, 0) }
        elsif flg && !@enabled
          @fs = 0
          @channel1.wave_duty_position = 0
          @channel2.wave_duty_position = 0
          @channel3.wave_duty_position = 0
        end
        @enabled = flg
      when 0xff30..0xff3f then @channel3.wave_ram[(addr - 0xff30)] = val
      else raise "Invalid APU write at #{addr.to_s(16)}"
      end
    end
  end
end

# frozen_string_literal: true


module Rubyboy
  module Cartridge
    class Factory
      def self.create(rom, ram)
        case rom.cartridge_type
        when 0x00
          Nombc.new(rom)
        when 0x01..0x03
          Mbc1.new(rom, ram)
        when 0x08..0x09
          Nombc.new(rom)
        else
          raise "Unsupported cartridge type: #{rom.cartridge_type}"
        end
      end
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  module Cartridge
    class Mbc1
      def initialize(rom, ram)
        @rom = rom
        @ram = ram
        @rom_bank = 1
        @ram_bank = 0
        @ram_enable = false
        @ram_banking_mode = false
      end

      def read_byte(addr)
        case (addr >> 12)
        when 0x0, 0x1, 0x2, 0x3
          @rom.data[addr]
        when 0x4, 0x5, 0x6, 0x7
          @rom.data[addr + ((@rom_bank - 1) << 14)]
        when 0xa, 0xb
          if @ram_enable
            if @ram_banking_mode
              @ram.eram[addr - 0xa000 + (@ram_bank << 11)]
            else
              @ram.eram[addr - 0xa000]
            end
          else
            0xff
          end
        end
      end

      def write_byte(addr, value)
        case addr >> 12
        when 0x0, 0x1
          @ram_enable = value & 0x0f == 0x0a
        when 0x2, 0x3
          @rom_bank = value & 0x1f
          @rom_bank = 1 if @rom_bank == 0
        when 0x4, 0x5
          @ram_bank = value & 0x03
        when 0x6, 0x7
          @ram_banking_mode = value & 0x01 == 0x01
        when 0xa, 0xb
          if @ram_enable
            if @ram_banking_mode
              @ram.eram[addr - 0xa000 + (@ram_bank << 11)] = value
            else
              @ram.eram[addr - 0xa000] = value
            end
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  module Cartridge
    class Nombc
      def initialize(rom)
        @rom = rom
      end

      def read_byte(addr)
        case addr
        when 0x0000..0x7fff
          @rom.data[addr]
        else
          raise "not implemented: read_byte #{addr}"
        end
      end

      def write_byte(_addr, _value)
        # do nothing
      end
    end
  end
end

# frozen_string_literal: true


module Rubyboy
  class Cpu
    def initialize(bus, interrupt)
      @bus = bus
      @interrupt = interrupt
      @registers = Registers.new

      @pc = 0x0100
      @sp = 0xfffe
      @ime = false
      @ime_delay = false
      @halted = false
    end

    def exec
      opcode = read_byte(@pc)
      # print_log(opcode)

      @halted &= @interrupt.interrupts == 0

      return 16 if @halted

      if @ime && @interrupt.interrupts > 0
        pcs = [0x0040, 0x0048, 0x0050, 0x0058, 0x0060]
        5.times do |i|
          next if @interrupt.interrupts[i] == 0

          @interrupt.reset_flag(i)
          @ime = false
          @sp -= 2
          @bus.write_word(@sp, @pc)
          @pc = pcs[i]

          break
        end

        return 20
      else
        increment_pc
      end

      if @ime_delay
        @ime_delay = false
        @ime = true
      end

      case opcode
      when 0x00 then 4 # NOP
      when 0x01 then ld16(:bc, :immediate16, cycles: 12)
      when 0x02 then ld8(:indirect_bc, :a, cycles: 8)
      when 0x03 then inc16(:bc, cycles: 8)
      when 0x04 then inc8(:b, cycles: 4)
      when 0x05 then dec8(:b, cycles: 4)
      when 0x06 then ld8(:b, :immediate8, cycles: 8)
      when 0x07 then rlca(cycles: 4)
      when 0x08 then ld16(:direct16, :sp, cycles: 20)
      when 0x09 then add16(:hl, :bc, cycles: 8)
      when 0x0a then ld8(:a, :indirect_bc, cycles: 8)
      when 0x0b then dec16(:bc, cycles: 8)
      when 0x0c then inc8(:c, cycles: 4)
      when 0x0d then dec8(:c, cycles: 4)
      when 0x0e then ld8(:c, :immediate8, cycles: 8)
      when 0x0f then rrca(cycles: 4)
      when 0x10 then 4 # STOP
      when 0x11 then ld16(:de, :immediate16, cycles: 12)
      when 0x12 then ld8(:indirect_de, :a, cycles: 8)
      when 0x13 then inc16(:de, cycles: 8)
      when 0x14 then inc8(:d, cycles: 4)
      when 0x15 then dec8(:d, cycles: 4)
      when 0x16 then ld8(:d, :immediate8, cycles: 8)
      when 0x17 then rla(cycles: 4)
      when 0x18 then jr(condition: true)
      when 0x19 then add16(:hl, :de, cycles: 8)
      when 0x1a then ld8(:a, :indirect_de, cycles: 8)
      when 0x1b then dec16(:de, cycles: 8)
      when 0x1c then inc8(:e, cycles: 4)
      when 0x1d then dec8(:e, cycles: 4)
      when 0x1e then ld8(:e, :immediate8, cycles: 8)
      when 0x1f then rra(cycles: 4)
      when 0x20 then jr(condition: !flag_z)
      when 0x21 then ld16(:hl, :immediate16, cycles: 12)
      when 0x22 then ld8(:hl_inc, :a, cycles: 8)
      when 0x23 then inc16(:hl, cycles: 8)
      when 0x24 then inc8(:h, cycles: 4)
      when 0x25 then dec8(:h, cycles: 4)
      when 0x26 then ld8(:h, :immediate8, cycles: 8)
      when 0x27 then daa(cycles: 4)
      when 0x28 then jr(condition: flag_z)
      when 0x29 then add16(:hl, :hl, cycles: 8)
      when 0x2a then ld8(:a, :hl_inc, cycles: 8)
      when 0x2b then dec16(:hl, cycles: 8)
      when 0x2c then inc8(:l, cycles: 4)
      when 0x2d then dec8(:l, cycles: 4)
      when 0x2e then ld8(:l, :immediate8, cycles: 8)
      when 0x2f then cpl(cycles: 4)
      when 0x30 then jr(condition: !flag_c)
      when 0x31 then ld16(:sp, :immediate16, cycles: 12)
      when 0x32 then ld8(:hl_dec, :a, cycles: 8)
      when 0x33 then inc16(:sp, cycles: 8)
      when 0x34 then inc8(:indirect_hl, cycles: 12)
      when 0x35 then dec8(:indirect_hl, cycles: 12)
      when 0x36 then ld8(:indirect_hl, :immediate8, cycles: 12)
      when 0x37 then scf(cycles: 4)
      when 0x38 then jr(condition: flag_c)
      when 0x39 then add16(:hl, :sp, cycles: 8)
      when 0x3a then ld8(:a, :hl_dec, cycles: 8)
      when 0x3b then dec16(:sp, cycles: 8)
      when 0x3c then inc8(:a, cycles: 4)
      when 0x3d then dec8(:a, cycles: 4)
      when 0x3e then ld8(:a, :immediate8, cycles: 8)
      when 0x3f then ccf(cycles: 4)
      when 0x40 then ld8(:b, :b, cycles: 4)
      when 0x41 then ld8(:b, :c, cycles: 4)
      when 0x42 then ld8(:b, :d, cycles: 4)
      when 0x43 then ld8(:b, :e, cycles: 4)
      when 0x44 then ld8(:b, :h, cycles: 4)
      when 0x45 then ld8(:b, :l, cycles: 4)
      when 0x46 then ld8(:b, :indirect_hl, cycles: 8)
      when 0x47 then ld8(:b, :a, cycles: 4)
      when 0x48 then ld8(:c, :b, cycles: 4)
      when 0x49 then ld8(:c, :c, cycles: 4)
      when 0x4a then ld8(:c, :d, cycles: 4)
      when 0x4b then ld8(:c, :e, cycles: 4)
      when 0x4c then ld8(:c, :h, cycles: 4)
      when 0x4d then ld8(:c, :l, cycles: 4)
      when 0x4e then ld8(:c, :indirect_hl, cycles: 8)
      when 0x4f then ld8(:c, :a, cycles: 4)
      when 0x50 then ld8(:d, :b, cycles: 4)
      when 0x51 then ld8(:d, :c, cycles: 4)
      when 0x52 then ld8(:d, :d, cycles: 4)
      when 0x53 then ld8(:d, :e, cycles: 4)
      when 0x54 then ld8(:d, :h, cycles: 4)
      when 0x55 then ld8(:d, :l, cycles: 4)
      when 0x56 then ld8(:d, :indirect_hl, cycles: 8)
      when 0x57 then ld8(:d, :a, cycles: 4)
      when 0x58 then ld8(:e, :b, cycles: 4)
      when 0x59 then ld8(:e, :c, cycles: 4)
      when 0x5a then ld8(:e, :d, cycles: 4)
      when 0x5b then ld8(:e, :e, cycles: 4)
      when 0x5c then ld8(:e, :h, cycles: 4)
      when 0x5d then ld8(:e, :l, cycles: 4)
      when 0x5e then ld8(:e, :indirect_hl, cycles: 8)
      when 0x5f then ld8(:e, :a, cycles: 4)
      when 0x60 then ld8(:h, :b, cycles: 4)
      when 0x61 then ld8(:h, :c, cycles: 4)
      when 0x62 then ld8(:h, :d, cycles: 4)
      when 0x63 then ld8(:h, :e, cycles: 4)
      when 0x64 then ld8(:h, :h, cycles: 4)
      when 0x65 then ld8(:h, :l, cycles: 4)
      when 0x66 then ld8(:h, :indirect_hl, cycles: 8)
      when 0x67 then ld8(:h, :a, cycles: 4)
      when 0x68 then ld8(:l, :b, cycles: 4)
      when 0x69 then ld8(:l, :c, cycles: 4)
      when 0x6a then ld8(:l, :d, cycles: 4)
      when 0x6b then ld8(:l, :e, cycles: 4)
      when 0x6c then ld8(:l, :h, cycles: 4)
      when 0x6d then ld8(:l, :l, cycles: 4)
      when 0x6e then ld8(:l, :indirect_hl, cycles: 8)
      when 0x6f then ld8(:l, :a, cycles: 4)
      when 0x70 then ld8(:indirect_hl, :b, cycles: 8)
      when 0x71 then ld8(:indirect_hl, :c, cycles: 8)
      when 0x72 then ld8(:indirect_hl, :d, cycles: 8)
      when 0x73 then ld8(:indirect_hl, :e, cycles: 8)
      when 0x74 then ld8(:indirect_hl, :h, cycles: 8)
      when 0x75 then ld8(:indirect_hl, :l, cycles: 8)
      when 0x76 then halt(cycles: 4)
      when 0x77 then ld8(:indirect_hl, :a, cycles: 8)
      when 0x78 then ld8(:a, :b, cycles: 4)
      when 0x79 then ld8(:a, :c, cycles: 4)
      when 0x7a then ld8(:a, :d, cycles: 4)
      when 0x7b then ld8(:a, :e, cycles: 4)
      when 0x7c then ld8(:a, :h, cycles: 4)
      when 0x7d then ld8(:a, :l, cycles: 4)
      when 0x7e then ld8(:a, :indirect_hl, cycles: 8)
      when 0x7f then ld8(:a, :a, cycles: 4)
      when 0x80 then add8(:b, cycles: 4)
      when 0x81 then add8(:c, cycles: 4)
      when 0x82 then add8(:d, cycles: 4)
      when 0x83 then add8(:e, cycles: 4)
      when 0x84 then add8(:h, cycles: 4)
      when 0x85 then add8(:l, cycles: 4)
      when 0x86 then add8(:indirect_hl, cycles: 8)
      when 0x87 then add8(:a, cycles: 4)
      when 0x88 then adc8(:b, cycles: 4)
      when 0x89 then adc8(:c, cycles: 4)
      when 0x8a then adc8(:d, cycles: 4)
      when 0x8b then adc8(:e, cycles: 4)
      when 0x8c then adc8(:h, cycles: 4)
      when 0x8d then adc8(:l, cycles: 4)
      when 0x8e then adc8(:indirect_hl, cycles: 8)
      when 0x8f then adc8(:a, cycles: 4)
      when 0x90 then sub8(:b, cycles: 4)
      when 0x91 then sub8(:c, cycles: 4)
      when 0x92 then sub8(:d, cycles: 4)
      when 0x93 then sub8(:e, cycles: 4)
      when 0x94 then sub8(:h, cycles: 4)
      when 0x95 then sub8(:l, cycles: 4)
      when 0x96 then sub8(:indirect_hl, cycles: 8)
      when 0x97 then sub8(:a, cycles: 4)
      when 0x98 then sbc8(:b, cycles: 4)
      when 0x99 then sbc8(:c, cycles: 4)
      when 0x9a then sbc8(:d, cycles: 4)
      when 0x9b then sbc8(:e, cycles: 4)
      when 0x9c then sbc8(:h, cycles: 4)
      when 0x9d then sbc8(:l, cycles: 4)
      when 0x9e then sbc8(:indirect_hl, cycles: 8)
      when 0x9f then sbc8(:a, cycles: 4)
      when 0xa0 then and8(:b, cycles: 4)
      when 0xa1 then and8(:c, cycles: 4)
      when 0xa2 then and8(:d, cycles: 4)
      when 0xa3 then and8(:e, cycles: 4)
      when 0xa4 then and8(:h, cycles: 4)
      when 0xa5 then and8(:l, cycles: 4)
      when 0xa6 then and8(:indirect_hl, cycles: 8)
      when 0xa7 then and8(:a, cycles: 4)
      when 0xa8 then xor8(:b, cycles: 4)
      when 0xa9 then xor8(:c, cycles: 4)
      when 0xaa then xor8(:d, cycles: 4)
      when 0xab then xor8(:e, cycles: 4)
      when 0xac then xor8(:h, cycles: 4)
      when 0xad then xor8(:l, cycles: 4)
      when 0xae then xor8(:indirect_hl, cycles: 8)
      when 0xaf then xor8(:a, cycles: 4)
      when 0xb0 then or8(:b, cycles: 4)
      when 0xb1 then or8(:c, cycles: 4)
      when 0xb2 then or8(:d, cycles: 4)
      when 0xb3 then or8(:e, cycles: 4)
      when 0xb4 then or8(:h, cycles: 4)
      when 0xb5 then or8(:l, cycles: 4)
      when 0xb6 then or8(:indirect_hl, cycles: 8)
      when 0xb7 then or8(:a, cycles: 4)
      when 0xb8 then cp8(:b, cycles: 4)
      when 0xb9 then cp8(:c, cycles: 4)
      when 0xba then cp8(:d, cycles: 4)
      when 0xbb then cp8(:e, cycles: 4)
      when 0xbc then cp8(:h, cycles: 4)
      when 0xbd then cp8(:l, cycles: 4)
      when 0xbe then cp8(:indirect_hl, cycles: 8)
      when 0xbf then cp8(:a, cycles: 4)
      when 0xc0 then ret_if(condition: !flag_z)
      when 0xc1 then pop16(:bc, cycles: 12)
      when 0xc2 then jp(:immediate16, condition: !flag_z)
      when 0xc3 then jp(:immediate16, condition: true)
      when 0xc4 then call16(:immediate16, condition: !flag_z)
      when 0xc5 then push16(:bc, cycles: 16)
      when 0xc6 then add8(:immediate8, cycles: 8)
      when 0xc7 then rst(0x00, cycles: 16)
      when 0xc8 then ret_if(condition: flag_z)
      when 0xc9 then ret(cycles: 16)
      when 0xca then jp(:immediate16, condition: flag_z)
      when 0xcc then call16(:immediate16, condition: flag_z)
      when 0xcd then call16(:immediate16, condition: true)
      when 0xce then adc8(:immediate8, cycles: 8)
      when 0xcf then rst(0x08, cycles: 16)
      when 0xd0 then ret_if(condition: !flag_c)
      when 0xd1 then pop16(:de, cycles: 12)
      when 0xd2 then jp(:immediate16, condition: !flag_c)
      when 0xd4 then call16(:immediate16, condition: !flag_c)
      when 0xd5 then push16(:de, cycles: 16)
      when 0xd6 then sub8(:immediate8, cycles: 8)
      when 0xd7 then rst(0x10, cycles: 16)
      when 0xd8 then ret_if(condition: flag_c)
      when 0xd9 then reti(cycles: 16)
      when 0xda then jp(:immediate16, condition: flag_c)
      when 0xdc then call16(:immediate16, condition: flag_c)
      when 0xde then sbc8(:immediate8, cycles: 8)
      when 0xdf then rst(0x18, cycles: 16)
      when 0xe0 then ld8(:ff00, :a, cycles: 12)
      when 0xe1 then pop16(:hl, cycles: 12)
      when 0xe2 then ld8(:ff00_c, :a, cycles: 8)
      when 0xe5 then push16(:hl, cycles: 16)
      when 0xe6 then and8(:immediate8, cycles: 8)
      when 0xe7 then rst(0x20, cycles: 16)
      when 0xe8 then add_sp_r8(cycles: 16)
      when 0xe9 then jp_hl(cycles: 4)
      when 0xea then ld8(:direct8, :a, cycles: 16)
      when 0xee then xor8(:immediate8, cycles: 8)
      when 0xef then rst(0x28, cycles: 16)
      when 0xf0 then ld8(:a, :ff00, cycles: 12)
      when 0xf1 then pop16(:af, cycles: 12)
      when 0xf2 then ld8(:a, :ff00_c, cycles: 8)
      when 0xf3 then di(cycles: 4)
      when 0xf5 then push16(:af, cycles: 16)
      when 0xf6 then or8(:immediate8, cycles: 8)
      when 0xf7 then rst(0x30, cycles: 16)
      when 0xf8 then ld_hl_sp_r8(cycles: 12)
      when 0xf9 then ld16(:sp, :hl, cycles: 8)
      when 0xfa then ld8(:a, :direct8, cycles: 16)
      when 0xfb then ei(cycles: 4)
      when 0xfe then cp8(:immediate8, cycles: 8)
      when 0xff then rst(0x38, cycles: 16)
      when 0xcb # CB prefix
        opcode = read_byte_and_advance_pc

        case opcode
        when 0x00 then rlc8(:b, cycles: 8)
        when 0x01 then rlc8(:c, cycles: 8)
        when 0x02 then rlc8(:d, cycles: 8)
        when 0x03 then rlc8(:e, cycles: 8)
        when 0x04 then rlc8(:h, cycles: 8)
        when 0x05 then rlc8(:l, cycles: 8)
        when 0x06 then rlc8(:indirect_hl, cycles: 16)
        when 0x07 then rlc8(:a, cycles: 8)
        when 0x08 then rrc8(:b, cycles: 8)
        when 0x09 then rrc8(:c, cycles: 8)
        when 0x0a then rrc8(:d, cycles: 8)
        when 0x0b then rrc8(:e, cycles: 8)
        when 0x0c then rrc8(:h, cycles: 8)
        when 0x0d then rrc8(:l, cycles: 8)
        when 0x0e then rrc8(:indirect_hl, cycles: 16)
        when 0x0f then rrc8(:a, cycles: 8)
        when 0x10 then rl8(:b, cycles: 8)
        when 0x11 then rl8(:c, cycles: 8)
        when 0x12 then rl8(:d, cycles: 8)
        when 0x13 then rl8(:e, cycles: 8)
        when 0x14 then rl8(:h, cycles: 8)
        when 0x15 then rl8(:l, cycles: 8)
        when 0x16 then rl8(:indirect_hl, cycles: 16)
        when 0x17 then rl8(:a, cycles: 8)
        when 0x18 then rr8(:b, cycles: 8)
        when 0x19 then rr8(:c, cycles: 8)
        when 0x1a then rr8(:d, cycles: 8)
        when 0x1b then rr8(:e, cycles: 8)
        when 0x1c then rr8(:h, cycles: 8)
        when 0x1d then rr8(:l, cycles: 8)
        when 0x1e then rr8(:indirect_hl, cycles: 16)
        when 0x1f then rr8(:a, cycles: 8)
        when 0x20 then sla8(:b, cycles: 8)
        when 0x21 then sla8(:c, cycles: 8)
        when 0x22 then sla8(:d, cycles: 8)
        when 0x23 then sla8(:e, cycles: 8)
        when 0x24 then sla8(:h, cycles: 8)
        when 0x25 then sla8(:l, cycles: 8)
        when 0x26 then sla8(:indirect_hl, cycles: 16)
        when 0x27 then sla8(:a, cycles: 8)
        when 0x28 then sra8(:b, cycles: 8)
        when 0x29 then sra8(:c, cycles: 8)
        when 0x2a then sra8(:d, cycles: 8)
        when 0x2b then sra8(:e, cycles: 8)
        when 0x2c then sra8(:h, cycles: 8)
        when 0x2d then sra8(:l, cycles: 8)
        when 0x2e then sra8(:indirect_hl, cycles: 16)
        when 0x2f then sra8(:a, cycles: 8)
        when 0x30 then swap8(:b, cycles: 8)
        when 0x31 then swap8(:c, cycles: 8)
        when 0x32 then swap8(:d, cycles: 8)
        when 0x33 then swap8(:e, cycles: 8)
        when 0x34 then swap8(:h, cycles: 8)
        when 0x35 then swap8(:l, cycles: 8)
        when 0x36 then swap8(:indirect_hl, cycles: 16)
        when 0x37 then swap8(:a, cycles: 8)
        when 0x38 then srl8(:b, cycles: 8)
        when 0x39 then srl8(:c, cycles: 8)
        when 0x3a then srl8(:d, cycles: 8)
        when 0x3b then srl8(:e, cycles: 8)
        when 0x3c then srl8(:h, cycles: 8)
        when 0x3d then srl8(:l, cycles: 8)
        when 0x3e then srl8(:indirect_hl, cycles: 16)
        when 0x3f then srl8(:a, cycles: 8)
        when 0x40 then bit8(0, :b, cycles: 8)
        when 0x41 then bit8(0, :c, cycles: 8)
        when 0x42 then bit8(0, :d, cycles: 8)
        when 0x43 then bit8(0, :e, cycles: 8)
        when 0x44 then bit8(0, :h, cycles: 8)
        when 0x45 then bit8(0, :l, cycles: 8)
        when 0x46 then bit8(0, :indirect_hl, cycles: 12)
        when 0x47 then bit8(0, :a, cycles: 8)
        when 0x48 then bit8(1, :b, cycles: 8)
        when 0x49 then bit8(1, :c, cycles: 8)
        when 0x4a then bit8(1, :d, cycles: 8)
        when 0x4b then bit8(1, :e, cycles: 8)
        when 0x4c then bit8(1, :h, cycles: 8)
        when 0x4d then bit8(1, :l, cycles: 8)
        when 0x4e then bit8(1, :indirect_hl, cycles: 12)
        when 0x4f then bit8(1, :a, cycles: 8)
        when 0x50 then bit8(2, :b, cycles: 8)
        when 0x51 then bit8(2, :c, cycles: 8)
        when 0x52 then bit8(2, :d, cycles: 8)
        when 0x53 then bit8(2, :e, cycles: 8)
        when 0x54 then bit8(2, :h, cycles: 8)
        when 0x55 then bit8(2, :l, cycles: 8)
        when 0x56 then bit8(2, :indirect_hl, cycles: 12)
        when 0x57 then bit8(2, :a, cycles: 8)
        when 0x58 then bit8(3, :b, cycles: 8)
        when 0x59 then bit8(3, :c, cycles: 8)
        when 0x5a then bit8(3, :d, cycles: 8)
        when 0x5b then bit8(3, :e, cycles: 8)
        when 0x5c then bit8(3, :h, cycles: 8)
        when 0x5d then bit8(3, :l, cycles: 8)
        when 0x5e then bit8(3, :indirect_hl, cycles: 12)
        when 0x5f then bit8(3, :a, cycles: 8)
        when 0x60 then bit8(4, :b, cycles: 8)
        when 0x61 then bit8(4, :c, cycles: 8)
        when 0x62 then bit8(4, :d, cycles: 8)
        when 0x63 then bit8(4, :e, cycles: 8)
        when 0x64 then bit8(4, :h, cycles: 8)
        when 0x65 then bit8(4, :l, cycles: 8)
        when 0x66 then bit8(4, :indirect_hl, cycles: 12)
        when 0x67 then bit8(4, :a, cycles: 8)
        when 0x68 then bit8(5, :b, cycles: 8)
        when 0x69 then bit8(5, :c, cycles: 8)
        when 0x6a then bit8(5, :d, cycles: 8)
        when 0x6b then bit8(5, :e, cycles: 8)
        when 0x6c then bit8(5, :h, cycles: 8)
        when 0x6d then bit8(5, :l, cycles: 8)
        when 0x6e then bit8(5, :indirect_hl, cycles: 12)
        when 0x6f then bit8(5, :a, cycles: 8)
        when 0x70 then bit8(6, :b, cycles: 8)
        when 0x71 then bit8(6, :c, cycles: 8)
        when 0x72 then bit8(6, :d, cycles: 8)
        when 0x73 then bit8(6, :e, cycles: 8)
        when 0x74 then bit8(6, :h, cycles: 8)
        when 0x75 then bit8(6, :l, cycles: 8)
        when 0x76 then bit8(6, :indirect_hl, cycles: 12)
        when 0x77 then bit8(6, :a, cycles: 8)
        when 0x78 then bit8(7, :b, cycles: 8)
        when 0x79 then bit8(7, :c, cycles: 8)
        when 0x7a then bit8(7, :d, cycles: 8)
        when 0x7b then bit8(7, :e, cycles: 8)
        when 0x7c then bit8(7, :h, cycles: 8)
        when 0x7d then bit8(7, :l, cycles: 8)
        when 0x7e then bit8(7, :indirect_hl, cycles: 12)
        when 0x7f then bit8(7, :a, cycles: 8)
        when 0x80 then res8(0, :b, cycles: 8)
        when 0x81 then res8(0, :c, cycles: 8)
        when 0x82 then res8(0, :d, cycles: 8)
        when 0x83 then res8(0, :e, cycles: 8)
        when 0x84 then res8(0, :h, cycles: 8)
        when 0x85 then res8(0, :l, cycles: 8)
        when 0x86 then res8(0, :indirect_hl, cycles: 16)
        when 0x87 then res8(0, :a, cycles: 8)
        when 0x88 then res8(1, :b, cycles: 8)
        when 0x89 then res8(1, :c, cycles: 8)
        when 0x8a then res8(1, :d, cycles: 8)
        when 0x8b then res8(1, :e, cycles: 8)
        when 0x8c then res8(1, :h, cycles: 8)
        when 0x8d then res8(1, :l, cycles: 8)
        when 0x8e then res8(1, :indirect_hl, cycles: 16)
        when 0x8f then res8(1, :a, cycles: 8)
        when 0x90 then res8(2, :b, cycles: 8)
        when 0x91 then res8(2, :c, cycles: 8)
        when 0x92 then res8(2, :d, cycles: 8)
        when 0x93 then res8(2, :e, cycles: 8)
        when 0x94 then res8(2, :h, cycles: 8)
        when 0x95 then res8(2, :l, cycles: 8)
        when 0x96 then res8(2, :indirect_hl, cycles: 16)
        when 0x97 then res8(2, :a, cycles: 8)
        when 0x98 then res8(3, :b, cycles: 8)
        when 0x99 then res8(3, :c, cycles: 8)
        when 0x9a then res8(3, :d, cycles: 8)
        when 0x9b then res8(3, :e, cycles: 8)
        when 0x9c then res8(3, :h, cycles: 8)
        when 0x9d then res8(3, :l, cycles: 8)
        when 0x9e then res8(3, :indirect_hl, cycles: 16)
        when 0x9f then res8(3, :a, cycles: 8)
        when 0xa0 then res8(4, :b, cycles: 8)
        when 0xa1 then res8(4, :c, cycles: 8)
        when 0xa2 then res8(4, :d, cycles: 8)
        when 0xa3 then res8(4, :e, cycles: 8)
        when 0xa4 then res8(4, :h, cycles: 8)
        when 0xa5 then res8(4, :l, cycles: 8)
        when 0xa6 then res8(4, :indirect_hl, cycles: 16)
        when 0xa7 then res8(4, :a, cycles: 8)
        when 0xa8 then res8(5, :b, cycles: 8)
        when 0xa9 then res8(5, :c, cycles: 8)
        when 0xaa then res8(5, :d, cycles: 8)
        when 0xab then res8(5, :e, cycles: 8)
        when 0xac then res8(5, :h, cycles: 8)
        when 0xad then res8(5, :l, cycles: 8)
        when 0xae then res8(5, :indirect_hl, cycles: 16)
        when 0xaf then res8(5, :a, cycles: 8)
        when 0xb0 then res8(6, :b, cycles: 8)
        when 0xb1 then res8(6, :c, cycles: 8)
        when 0xb2 then res8(6, :d, cycles: 8)
        when 0xb3 then res8(6, :e, cycles: 8)
        when 0xb4 then res8(6, :h, cycles: 8)
        when 0xb5 then res8(6, :l, cycles: 8)
        when 0xb6 then res8(6, :indirect_hl, cycles: 16)
        when 0xb7 then res8(6, :a, cycles: 8)
        when 0xb8 then res8(7, :b, cycles: 8)
        when 0xb9 then res8(7, :c, cycles: 8)
        when 0xba then res8(7, :d, cycles: 8)
        when 0xbb then res8(7, :e, cycles: 8)
        when 0xbc then res8(7, :h, cycles: 8)
        when 0xbd then res8(7, :l, cycles: 8)
        when 0xbe then res8(7, :indirect_hl, cycles: 16)
        when 0xbf then res8(7, :a, cycles: 8)
        when 0xc0 then set8(0, :b, cycles: 8)
        when 0xc1 then set8(0, :c, cycles: 8)
        when 0xc2 then set8(0, :d, cycles: 8)
        when 0xc3 then set8(0, :e, cycles: 8)
        when 0xc4 then set8(0, :h, cycles: 8)
        when 0xc5 then set8(0, :l, cycles: 8)
        when 0xc6 then set8(0, :indirect_hl, cycles: 16)
        when 0xc7 then set8(0, :a, cycles: 8)
        when 0xc8 then set8(1, :b, cycles: 8)
        when 0xc9 then set8(1, :c, cycles: 8)
        when 0xca then set8(1, :d, cycles: 8)
        when 0xcb then set8(1, :e, cycles: 8)
        when 0xcc then set8(1, :h, cycles: 8)
        when 0xcd then set8(1, :l, cycles: 8)
        when 0xce then set8(1, :indirect_hl, cycles: 16)
        when 0xcf then set8(1, :a, cycles: 8)
        when 0xd0 then set8(2, :b, cycles: 8)
        when 0xd1 then set8(2, :c, cycles: 8)
        when 0xd2 then set8(2, :d, cycles: 8)
        when 0xd3 then set8(2, :e, cycles: 8)
        when 0xd4 then set8(2, :h, cycles: 8)
        when 0xd5 then set8(2, :l, cycles: 8)
        when 0xd6 then set8(2, :indirect_hl, cycles: 16)
        when 0xd7 then set8(2, :a, cycles: 8)
        when 0xd8 then set8(3, :b, cycles: 8)
        when 0xd9 then set8(3, :c, cycles: 8)
        when 0xda then set8(3, :d, cycles: 8)
        when 0xdb then set8(3, :e, cycles: 8)
        when 0xdc then set8(3, :h, cycles: 8)
        when 0xdd then set8(3, :l, cycles: 8)
        when 0xde then set8(3, :indirect_hl, cycles: 16)
        when 0xdf then set8(3, :a, cycles: 8)
        when 0xe0 then set8(4, :b, cycles: 8)
        when 0xe1 then set8(4, :c, cycles: 8)
        when 0xe2 then set8(4, :d, cycles: 8)
        when 0xe3 then set8(4, :e, cycles: 8)
        when 0xe4 then set8(4, :h, cycles: 8)
        when 0xe5 then set8(4, :l, cycles: 8)
        when 0xe6 then set8(4, :indirect_hl, cycles: 16)
        when 0xe7 then set8(4, :a, cycles: 8)
        when 0xe8 then set8(5, :b, cycles: 8)
        when 0xe9 then set8(5, :c, cycles: 8)
        when 0xea then set8(5, :d, cycles: 8)
        when 0xeb then set8(5, :e, cycles: 8)
        when 0xec then set8(5, :h, cycles: 8)
        when 0xed then set8(5, :l, cycles: 8)
        when 0xee then set8(5, :indirect_hl, cycles: 16)
        when 0xef then set8(5, :a, cycles: 8)
        when 0xf0 then set8(6, :b, cycles: 8)
        when 0xf1 then set8(6, :c, cycles: 8)
        when 0xf2 then set8(6, :d, cycles: 8)
        when 0xf3 then set8(6, :e, cycles: 8)
        when 0xf4 then set8(6, :h, cycles: 8)
        when 0xf5 then set8(6, :l, cycles: 8)
        when 0xf6 then set8(6, :indirect_hl, cycles: 16)
        when 0xf7 then set8(6, :a, cycles: 8)
        when 0xf8 then set8(7, :b, cycles: 8)
        when 0xf9 then set8(7, :c, cycles: 8)
        when 0xfa then set8(7, :d, cycles: 8)
        when 0xfb then set8(7, :e, cycles: 8)
        when 0xfc then set8(7, :h, cycles: 8)
        when 0xfd then set8(7, :l, cycles: 8)
        when 0xfe then set8(7, :indirect_hl, cycles: 16)
        when 0xff then set8(7, :a, cycles: 8)
        else
          raise "unknown opcode: 0xcb 0x#{'%02x' % opcode}"
        end
      else
        raise "unknown opcode: 0x#{'%02x' % opcode}"
      end
    end

    private

    def read_byte(addr)
      @bus.read_byte(addr)
    end

    def read_word(addr)
      @bus.read_word(addr)
    end

    def write_byte(addr, value)
      @bus.write_byte(addr, value)
    end

    def write_word(addr, value)
      @bus.write_word(addr, value)
    end

    def read_byte_and_advance_pc
      byte = read_byte(@pc)
      increment_pc
      byte
    end

    def read_word_and_advance_pc
      word = read_word(@pc)
      increment_pc_by_byte(2)
      word
    end

    def print_log(opcode)
      puts "PC: 0x#{'%04x' % @pc}, Opcode: 0x#{'%02x' % opcode}, AF: 0x#{'%04x' % @registers.af}, BC: 0x#{'%04x' % @registers.bc}, HL: 0x#{'%04x' % @registers.hl}, SP: 0x#{'%04x' % @sp}"
    end

    def flag_z
      @registers.f[7] == 1
    end

    def flag_n
      @registers.f[6] == 1
    end

    def flag_h
      @registers.f[5] == 1
    end

    def flag_c
      @registers.f[4] == 1
    end

    def update_flags(z: flag_z, n: flag_n, h: flag_h, c: flag_c)
      f_value = 0x00
      f_value |= 0x80 if z
      f_value |= 0x40 if n
      f_value |= 0x20 if h
      f_value |= 0x10 if c

      @registers.f = f_value
    end

    def bool_to_integer(bool)
      bool ? 1 : 0
    end

    def increment_pc
      increment_pc_by_byte(1)
    end

    def increment_pc_by_byte(byte)
      @pc += byte
    end

    def to_signed_byte(byte)
      byte &= 0xff
      byte > 127 ? byte - 256 : byte
    end

    def rlca(cycles:)
      a_value = @registers.a
      a_value = ((a_value << 1) | (a_value >> 7)) & 0xff
      @registers.a = a_value
      update_flags(
        z: false,
        n: false,
        h: false,
        c: a_value[0] == 1
      )

      cycles
    end

    def rrca(cycles:)
      a_value = @registers.a
      a_value = ((a_value >> 1) | (a_value << 7)) & 0xff
      @registers.a = a_value
      update_flags(
        z: false,
        n: false,
        h: false,
        c: a_value[7] == 1
      )

      cycles
    end

    def rra(cycles:)
      a_value = @registers.a
      cflag = a_value[0] == 1
      a_value = ((a_value >> 1) | (bool_to_integer(flag_c) << 7)) & 0xff
      @registers.a = a_value
      update_flags(
        z: false,
        n: false,
        h: false,
        c: cflag
      )

      cycles
    end

    def rla(cycles:)
      a_value = @registers.a
      cflag = a_value[7] == 1
      a_value = ((a_value << 1) | bool_to_integer(flag_c)) & 0xff
      @registers.a = a_value
      update_flags(
        z: false,
        n: false,
        h: false,
        c: cflag
      )

      cycles
    end

    def daa(cycles:)
      a_value = @registers.a
      if flag_n
        a_value -= 0x06 if flag_h
        a_value -= 0x60 if flag_c
      else
        if flag_c || a_value > 0x99
          a_value += 0x60
          update_flags(c: true)
        end
        a_value += 0x06 if flag_h || (a_value & 0x0f) > 0x09
      end

      @registers.a = a_value
      update_flags(
        z: @registers.a == 0,
        h: false
      )

      cycles
    end

    def cpl(cycles:)
      @registers.a = ~@registers.a
      update_flags(
        n: true,
        h: true
      )

      cycles
    end

    def scf(cycles:)
      update_flags(
        n: false,
        h: false,
        c: true
      )

      cycles
    end

    def ccf(cycles:)
      update_flags(
        n: false,
        h: false,
        c: !flag_c
      )

      cycles
    end

    def inc8(x, cycles:)
      value = (get_value(x) + 1) & 0xff
      set_value(x, value)
      update_flags(
        z: value == 0,
        n: false,
        h: (value & 0x0f) == 0
      )

      cycles
    end

    def inc16(x, cycles:)
      set_value(x, get_value(x) + 1)

      cycles
    end

    def dec8(x, cycles:)
      value = (get_value(x) - 1) & 0xff
      set_value(x, value)
      update_flags(
        z: value == 0,
        n: true,
        h: (value & 0x0f) == 0x0f
      )

      cycles
    end

    def dec16(x, cycles:)
      set_value(x, get_value(x) - 1)

      cycles
    end

    def add8(x, cycles:)
      a_value = @registers.a
      x_value = get_value(x)

      hflag = (a_value & 0x0f) + (x_value & 0x0f) > 0x0f
      cflag = a_value + x_value > 0xff

      a_value += x_value
      @registers.a = a_value
      update_flags(
        z: @registers.a == 0,
        n: false,
        h: hflag,
        c: cflag
      )

      cycles
    end

    def add16(x, y, cycles:)
      x_value = get_value(x)
      y_value = get_value(y)

      hflag = (x_value & 0x0fff) + (y_value & 0x0fff) > 0x0fff
      cflag = x_value + y_value > 0xffff

      set_value(x, x_value + y_value)
      update_flags(
        n: false,
        h: hflag,
        c: cflag
      )

      cycles
    end

    def add_sp_r8(cycles:)
      byte = to_signed_byte(read_byte_and_advance_pc)

      hflag = (@sp & 0x0f) + (byte & 0x0f) > 0x0f
      cflag = (@sp & 0xff) + (byte & 0xff) > 0xff

      @sp += byte
      @sp &= 0xffff
      update_flags(
        z: false,
        n: false,
        h: hflag,
        c: cflag
      )

      cycles
    end

    def sub8(x, cycles:)
      a_value = @registers.a
      x_value = get_value(x)

      hflag = (x_value & 0x0f) > (a_value & 0x0f)
      cflag = x_value > a_value
      a_value -= x_value
      @registers.a = a_value
      update_flags(
        z: a_value == 0,
        n: true,
        h: hflag,
        c: cflag
      )

      cycles
    end

    def adc8(x, cycles:)
      a_value = @registers.a
      x_value = get_value(x)
      c_value = bool_to_integer(flag_c)

      hflag = (a_value & 0x0f) + (x_value & 0x0f) + c_value > 0x0f
      cflag = a_value + x_value + c_value > 0xff
      a_value += x_value + c_value
      @registers.a = a_value
      update_flags(
        z: @registers.a == 0,
        n: false,
        h: hflag,
        c: cflag
      )

      cycles
    end

    def sbc8(x, cycles:)
      a_value = @registers.a
      x_value = get_value(x)
      c_value = bool_to_integer(flag_c)

      hflag = (x_value & 0x0f) + c_value > (a_value & 0x0f)
      cflag = x_value + c_value > a_value
      a_value -= x_value + c_value
      @registers.a = a_value
      update_flags(
        z: @registers.a == 0,
        n: true,
        h: hflag,
        c: cflag
      )

      cycles
    end

    def and8(x, cycles:)
      a_value = @registers.a & get_value(x)
      @registers.a = a_value
      update_flags(
        z: a_value == 0,
        n: false,
        h: true,
        c: false
      )

      cycles
    end

    def or8(x, cycles:)
      a_value = @registers.a | get_value(x)
      @registers.a = a_value
      update_flags(
        z: a_value == 0,
        n: false,
        h: false,
        c: false
      )

      cycles
    end

    def xor8(x, cycles:)
      a_value = @registers.a ^ get_value(x)
      @registers.a = a_value
      update_flags(
        z: a_value == 0,
        n: false,
        h: false,
        c: false
      )

      cycles
    end

    def push16(register16, cycles:)
      @sp -= 2
      write_word(@sp, get_value(register16))

      cycles
    end

    def pop16(register16, cycles:)
      set_value(register16, read_word(@sp))
      @sp += 2

      cycles
    end

    def halt(cycles:)
      @halted = true

      cycles
    end

    def ld8(x, y, cycles:)
      value = get_value(y)
      set_value(x, value)

      cycles
    end

    def ld16(x, y, cycles:)
      value = get_value(y)
      set_value(x, value)

      cycles
    end

    def ld_hl_sp_r8(cycles:)
      byte = to_signed_byte(read_byte_and_advance_pc)

      hflag = (@sp & 0x0f) + (byte & 0x0f) > 0x0f
      cflag = (@sp & 0xff) + (byte & 0xff) > 0xff
      @registers.hl = @sp + byte
      update_flags(
        z: false,
        n: false,
        h: hflag,
        c: cflag
      )

      cycles
    end

    def ei(cycles:)
      @ime_delay = true

      cycles
    end

    def di(cycles:)
      @ime_delay = false
      @ime = false

      cycles
    end

    def cp8(x, cycles:)
      a_value = @registers.a
      x_value = get_value(x)

      hflag = (x_value & 0x0f) > (a_value & 0x0f)
      cflag = x_value > a_value
      update_flags(
        z: a_value == x_value,
        n: true,
        h: hflag,
        c: cflag
      )

      cycles
    end

    def rst(addr, cycles:)
      @sp -= 2
      write_word(@sp, @pc)
      @pc = addr

      cycles
    end

    def jr(condition:)
      value = to_signed_byte(read_byte_and_advance_pc)
      @pc += value if condition

      condition ? 12 : 8
    end

    def jp(x, condition:)
      addr = get_value(x)
      @pc = addr if condition

      condition ? 16 : 12
    end

    def jp_hl(cycles:)
      @pc = @registers.hl

      cycles
    end

    def call16(x, condition:)
      addr = get_value(x)
      if condition
        @sp -= 2
        write_word(@sp, @pc)
        @pc = addr
      end

      condition ? 24 : 12
    end

    def ret(cycles:)
      @pc = read_word(@sp)
      @sp += 2

      cycles
    end

    def ret_if(condition:)
      ret(cycles: 16) if condition

      condition ? 20 : 8
    end

    def reti(cycles:)
      @ime = true
      ret(cycles:)
    end

    def rlc8(x, cycles:)
      value = get_value(x)
      value = (value << 1) | (value >> 7)
      set_value(x, value)
      update_flags(
        z: value == 0,
        n: false,
        h: false,
        c: value[0] == 1
      )

      cycles
    end

    def rrc8(x, cycles:)
      value = get_value(x)
      value = (value >> 1) | (value << 7)
      set_value(x, value)
      update_flags(
        z: value == 0,
        n: false,
        h: false,
        c: value[7] == 1
      )

      cycles
    end

    def rl8(x, cycles:)
      value = get_value(x)
      cflag = value[7] == 1
      value = ((value << 1) | bool_to_integer(flag_c)) & 0xff
      set_value(x, value)
      update_flags(
        z: value == 0,
        n: false,
        h: false,
        c: cflag
      )

      cycles
    end

    def rr8(x, cycles:)
      value = get_value(x)
      cflag = value[0] == 1
      value = (value >> 1) | (bool_to_integer(flag_c) << 7)
      set_value(x, value)
      update_flags(
        z: value == 0,
        n: false,
        h: false,
        c: cflag
      )

      cycles
    end

    def sla8(x, cycles:)
      value = get_value(x)
      cflag = value[7] == 1
      value <<= 1
      value &= 0xff
      set_value(x, value)
      update_flags(
        z: value == 0,
        n: false,
        h: false,
        c: cflag
      )

      cycles
    end

    def sra8(x, cycles:)
      value = get_value(x)
      cflag = value[0] == 1
      value = (value >> 1) | (value[7] << 7)
      set_value(x, value)
      update_flags(
        z: value == 0,
        n: false,
        h: false,
        c: cflag
      )

      cycles
    end

    def swap8(x, cycles:)
      value = get_value(x)
      value = ((value & 0x0f) << 4) | ((value & 0xf0) >> 4)
      set_value(x, value)
      update_flags(
        z: value == 0,
        n: false,
        h: false,
        c: false
      )

      cycles
    end

    def srl8(x, cycles:)
      value = get_value(x)
      cflag = value[0] == 1
      value >>= 1
      set_value(x, value)
      update_flags(
        z: value == 0,
        n: false,
        h: false,
        c: cflag
      )

      cycles
    end

    def bit8(n, x, cycles:)
      value = get_value(x)
      update_flags(
        z: value[n] == 0,
        n: false,
        h: true
      )

      cycles
    end

    def res8(n, x, cycles:)
      value = get_value(x)
      value &= ((~(1 << n)) & 0xff)
      set_value(x, value)

      cycles
    end

    def set8(n, x, cycles:)
      value = get_value(x)
      value |= (1 << n)
      set_value(x, value)

      cycles
    end

    def get_value(operand)
      case operand
      when :a then @registers.a
      when :b then @registers.b
      when :c then @registers.c
      when :d then @registers.d
      when :e then @registers.e
      when :h then @registers.h
      when :l then @registers.l
      when :f then @registers.f
      when :af then @registers.af
      when :bc then @registers.bc
      when :de then @registers.de
      when :hl then @registers.hl
      when :sp then @sp
      when :immediate8 then read_byte_and_advance_pc
      when :immediate16 then read_word_and_advance_pc
      when :direct8 then read_byte(read_word_and_advance_pc)
      when :direct16 then read_word(read_word_and_advance_pc)
      when :ff00 then read_byte(0xff00 + read_byte_and_advance_pc)
      when :ff00_c then read_byte(0xff00 + @registers.c)
      when :hl_inc
        value = read_byte(@registers.hl)
        @registers.hl += 1
        value
      when :hl_dec
        value = read_byte(@registers.hl)
        @registers.hl -= 1
        value
      when :indirect_hl then read_byte(@registers.hl)
      when :indirect_bc then read_byte(@registers.bc)
      when :indirect_de then read_byte(@registers.de)
      else raise "unknown operand: #{operand}"
      end
    end

    def set_value(operand, value)
      case operand
      when :a then @registers.a = value
      when :b then @registers.b = value
      when :c then @registers.c = value
      when :d then @registers.d = value
      when :e then @registers.e = value
      when :h then @registers.h = value
      when :l then @registers.l = value
      when :f then @registers.f = value
      when :af then @registers.af = value
      when :bc then @registers.bc = value
      when :de then @registers.de = value
      when :hl then @registers.hl = value
      when :sp then @sp = value & 0xffff
      when :direct8 then write_byte(read_word_and_advance_pc, value)
      when :direct16 then write_word(read_word_and_advance_pc, value)
      when :ff00 then write_byte(0xff00 + read_byte_and_advance_pc, value)
      when :ff00_c then write_byte(0xff00 + @registers.c, value)
      when :hl_inc
        write_byte(@registers.hl, value)
        @registers.hl += 1
      when :hl_dec
        write_byte(@registers.hl, value)
        @registers.hl -= 1
      when :indirect_hl then write_byte(@registers.hl, value)
      when :indirect_bc then write_byte(@registers.bc, value)
      when :indirect_de then write_byte(@registers.de, value)
      when :immediate8, :immediate16 then raise 'immediate type is read only'
      else raise "unknown operand: #{operand}"
      end
    end
  end
end

# frozen_string_literal: true

module Rubyboy
  class Bus
    def initialize(ppu, rom, ram, mbc, timer, interrupt, joypad, apu)
      @ppu = ppu
      @rom = rom
      @ram = ram
      @mbc = mbc
      @joypad = joypad
      @apu = apu
      @interrupt = interrupt
      @timer = timer
    end

    def read_byte(addr)
      case addr >> 12
      when 0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0xa, 0xb
        return @mbc.read_byte(addr)
      when 0x8, 0x9
        return @ppu.read_byte(addr)
      when 0xc
        return @ram.wram1[addr - 0xc000]
      when 0xd
        return @ram.wram2[addr - 0xd000]
      when 0xf
        case addr >> 8
        when 0xfe
          return @ppu.read_byte(addr) if addr <= 0xfe9f
        when 0xff
          last_byte = addr & 0xFF

          case last_byte
          when 0x00
            return @joypad.read_byte(addr)
          when 0x04, 0x05, 0x06, 0x07
            return @timer.read_byte(addr)
          when 0x0f
            return @interrupt.read_byte(addr)
          when 0x46
            return @ppu.read_byte(addr)
          when 0xff
            return @interrupt.read_byte(addr)
          end

          return @apu.read_byte(addr) if last_byte <= 0x26 && last_byte >= 0x10

          return @apu.read_byte(addr) if last_byte <= 0x3f && last_byte >= 0x30

          return @ppu.read_byte(addr) if last_byte <= 0x4b && last_byte >= 0x40

          return @ram.hram[addr - 0xff80] if last_byte <= 0xfe && last_byte >= 0x80
        end
      end

      0xff
    end

    def write_byte(addr, value)
      case addr >> 12
      when 0x0, 0x1, 0x2, 0x3, 0x4, 0x5, 0x6, 0x7, 0xa, 0xb
        return @mbc.write_byte(addr, value)
      when 0x8, 0x9
        return @ppu.write_byte(addr, value)
      when 0xc
        return @ram.wram1[addr - 0xc000] = value
      when 0xd
        return @ram.wram2[addr - 0xd000] = value
      when 0xf
        case addr >> 8
        when 0xfe
          return @ppu.write_byte(addr, value) if addr <= 0xfe9f
        when 0xff
          last_byte = addr & 0xFF

          case last_byte
          when 0x00
            return @joypad.write_byte(addr, value)
          when 0x04, 0x05, 0x06, 0x07
            return @timer.write_byte(addr, value)
          when 0x0f
            return @interrupt.write_byte(addr, value)
          when 0x46
            0xa0.times { |i| write_byte(0xfe00 + i, read_byte((value << 8) + i)) }
            return
          when 0xff
            return @interrupt.write_byte(addr, value)
          end

          return @apu.write_byte(addr, value) if last_byte <= 0x26 && last_byte >= 0x10

          return @apu.write_byte(addr, value) if last_byte <= 0x3f && last_byte >= 0x30

          return @ppu.write_byte(addr, value) if last_byte <= 0x4b && last_byte >= 0x40

          return @ram.hram[addr - 0xff80] = value if last_byte <= 0xfe && last_byte >= 0x80
        end
      end

      nil
    end

    def read_word(addr)
      read_byte(addr) + (read_byte(addr + 1) << 8)
    end

    def write_word(addr, value)
      write_byte(addr, value & 0xff)
      write_byte(addr + 1, value >> 8)
    end
  end
end

ROM_PATH = "/gb/rom.gb"
# --- interactive driver ------------------------------------------------------
# Protocol, one byte in / one frame out:
#   in   bit 0..3 = Right Left Up Down, bit 4..7 = A B Select Start.
#        The Game Boy joypad is active-low, so a set bit means NOT pressed and
#        the idle byte is 0xff... which would collide with quit, so the host
#        sends the pressed-high form and this side inverts.  0xfe = quit.
#   out  160 * 144 * 4 bytes, 0xAARRGGBB little-endian (what Ppu#buffer holds)
module Rubyboy
  class EmulatorWeb
    def initialize(rom_data)
      rom = Rom.new(rom_data)
      ram = Ram.new
      mbc = Cartridge::Factory.create(rom, ram)
      interrupt = Interrupt.new
      @ppu = Ppu.new(interrupt)
      @timer = Timer.new(interrupt)
      @joypad = Joypad.new(interrupt)
      @apu = Apu.new
      @bus = Bus.new(@ppu, rom, ram, mbc, @timer, interrupt, @joypad, @apu)
      @cpu = Cpu.new(@bus, interrupt)
    end

    def step(direction_key, action_key)
      @joypad.direction_button(direction_key)
      @joypad.action_button(action_key)
      loop do
        cycles = @cpu.exec
        @timer.step(cycles)
        return @ppu.buffer if @ppu.step(cycles)
      end
    end
  end
end

# rubyboy wants the ROM as an array of bytes, not a String (Rom#load_data
# compares the logo against an array of hex strings).
emu = Rubyboy::EmulatorWeb.new(File.binread(ROM_PATH).bytes)

# No palette: the Game Boy buffer is already 32-bit colour.  The marker keeps
# the wire format the same as the other pages, with an empty palette.
$stdout.write("PAL0")
$stdout.write(([0] * 768).pack("C*"))

loop do
  b = STDIN.read(1)
  break if b.nil?
  v = b.unpack1("C")
  break if v == 0xfe
  inv = (~v) & 0xff                      # pressed-high -> the joypad's active-low
  buf = emu.step(inv & 0x0f, (inv >> 4) & 0x0f)
  $stdout.write(buf.pack("L<*"))
  $stdout.flush
end
