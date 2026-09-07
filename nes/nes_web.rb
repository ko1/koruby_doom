unless File.respond_to?(:binread)
  class File
    def self.binread(path) = __binread(path)
    def self.read(path) = __binread(path)
  end
end
module Rnes
  VERSION = '0.2.1'.freeze
end

module Rnes
  module Errors
    class BaseError < ::StandardError
    end

    class BaseInvalidAddressError < BaseError
      # @param [Integer] address
      def initialize(address)
        @address = address
        super(to_s)
      end

      # @return [String]
      def to_s
        format('Invalid address: 0x%04X', @address)
      end
    end

    class InvalidAddressingModeError < BaseError
    end

    class InvalidCpuBusAddressError < BaseInvalidAddressError
    end

    class InvalidInesFormatError < BaseError
    end

    class InvalidOperationCodeError < BaseError
    end

    class InvalidOperationError < BaseError
    end

    class InvalidPpuAddressError < BaseInvalidAddressError
    end

    class InvalidPpuBusAddressError < BaseInvalidAddressError
    end

    class ProgramRomNotConnectedError < BaseError
    end

    class StackPointerOverflowError < BaseError
    end
  end
end

module Rnes
  class Image
    # @return [Integer]
    attr_reader :height

    # @return [Integer]
    attr_reader :width

    # @param [Integer] height
    # @param [Integer] width
    def initialize(height:, width:)
      @bytes = Array.new(height * width) do
        [0, 0, 0]
      end
      @height = height
      @width = width
    end

    # @param [Integer] x
    # @param [Integer] y
    def read(x:, y:)
      @bytes[@width * y + x]
    end

    # @param [Array<Integer>] rgb
    # @param [Integer] x
    # @param [Integer] y
    def write(value:, x:, y:)
      @bytes[@width * y + x] = value
    end
  end
end

module Rnes
  class Ram
    # @param [Integer] bytesize
    def initialize(bytesize:)
      @bytes = Array.new(bytesize).map do
        0
      end
    end

    # @param [Integer] address
    # @return [Integer]
    def read(address)
      @bytes[address]
    end

    # @param [Integer] address
    # @param [Integer] value
    # @return [Integer]
    def write(address, value)
      @bytes[address] = value
    end
  end
end

module Rnes
  class Rom
    # @param [Integer] bytes
    def initialize(bytes:)
      @bytes = bytes
    end

    # @return [Integer]
    def bytesize
      @bytes.length
    end

    # @param [Integer] address
    # @param [Integer] value
    def read(address)
      @bytes[address]
    end
  end
end

module Rnes
  class InesHeader
    BYTESIZE = 16

    PREFIX_BYTES = [
      0x4E, # N
      0x45, # E
      0x53, # S
      0x1A, # end-of-file in MS-DOS
    ].freeze

    # @param [Array<Integer>] bytes
    def initialize(bytes)
      @bytes = bytes
    end

    # @return [Integer]
    def bytesize
      BYTESIZE
    end

    # @return [Integer]
    def character_ram_bytesize
      @bytes[8]
    end

    # @return [Integer]
    def character_rom_bytesize
      @bytes[5] * 8 * 2**10
    end

    # @return [Boolean]
    def has_battery_backed_program_rom_bit?
      flags1[1] == 1
    end

    # @return [Boolean]
    def has_mirror_ignoring_bit?
      flags1[3] == 1
    end

    # @note Trainers are 512 bytes of code which is loaded into $7000 before the game starts for hacker use.
    # @return [Boolean]
    def has_trainer_bit?
      flags1[2] == 1
    end

    # @return [Boolean]
    def has_vertical_mirroring_bit?
      flags1[0] == 1
    end

    # @return [Integer]
    def mapper_number
      flags2 & 0b11110000 | flags1 >> 4
    end

    # @return [Integer]
    def program_rom_bytesize
      @bytes[4] * 16 * 2**10
    end

    # @return [Integer]
    def trainer_bytesize
      if has_trainer_bit?
        512
      else
        0
      end
    end

    # @return [Boolean]
    def valid?
      @bytes[0..3] == PREFIX_BYTES
    end

    private

    # @return [Integer]
    def flags1
      @bytes[6]
    end

    # @return [Integer]
    def flags2
      @bytes[7]
    end
  end
end


module Rnes
  class RomLoader
    # @param [Array<Integer>] bytes
    def initialize(bytes)
      @bytes = bytes
    end

    # @return [Rnes::Rom]
    # @raise [Rnes::Errors::InvalidInesFormatError]
    def character_rom
      validate!
      ::Rnes::Rom.new(bytes: character_rom_bytes)
    end

    # @return [Rnes::Rom]
    # @raise [Rnes::Errors::InvalidInesFormatError]
    def program_rom
      validate!
      ::Rnes::Rom.new(bytes: program_rom_bytes)
    end

    # @return [Rnes::Rom]
    # @raise [Rnes::Errors::InvalidInesFormatError]
    def trainer_rom
      validate!
      ::Rnes::Rom.new(bytes: trainer_bytes)
    end

    private

    # @return [Array<Integer>]
    def character_rom_bytes
      @bytes.slice(character_rom_index, character_rom_bytesize)
    end

    # @return [Integer]
    def character_rom_bytesize
      ines_header.character_rom_bytesize
    end

    # @return [Integer]
    def character_rom_index
      program_rom_index + program_rom_bytesize
    end

    # @return [Rnes::InesHeader]
    def ines_header
      @ines_header ||= ::Rnes::InesHeader.new(@bytes)
    end

    # @return [Array<Integer>]
    def program_rom_bytes
      @bytes.slice(program_rom_index, program_rom_bytesize)
    end

    # @return [Integer]
    def program_rom_bytesize
      @program_rom_bytesize ||= ines_header.program_rom_bytesize
    end

    # @return [Integer]
    def program_rom_index
      @program_rom_index ||= trainer_index + trainer_bytesize
    end

    # @return [Array<Integer>]
    def trainer_bytes
      @bytes.slice(trainer_index, trainer_bytesize)
    end

    # @return [Integer]
    def trainer_bytesize
      ines_header.trainer_bytesize
    end

    # @return [Integer]
    def trainer_index
      ines_header.bytesize
    end

    # @return [Boolean]
    def valid?
      ines_header.valid?
    end

    # @raise [Rnes::Errors::InvalidInesFormatError]
    def validate!
      unless valid?
        raise ::Rnes::Errors::InvalidInesFormatError
      end
    end
  end
end

module Rnes
  class InterruptLine
    # @return [Boolean]
    attr_reader :irq

    # @return [Boolean]
    attr_reader :nmi

    def initialize
      @irq = false
      @nmi = false
    end

    def assert_irq
      @irq = true
    end

    def assert_nmi
      @nmi = true
    end

    def deassert_irq
      @irq = false
    end

    def deassert_nmi
      @nmi = false
    end
  end
end

module Rnes
  class Keypad
    KEY_MAP = {
      '.' => 0,
      ',' => 1,
      'n' => 2,
      'm' => 3,
      'w' => 4,
      's' => 5,
      'a' => 6,
      'd' => 7,
    }.freeze

    def initialize
      @buffer = 0
      @copy = 0
      @index = 0
    end

    def check
      character = ::STDIN.read_nonblock(1)
      index = KEY_MAP[character]
      if index
        @buffer |= 1 << index
      end
    rescue ::EOFError
      # Rescue on no STDIN environment (e.g. CircleCI).
    rescue ::IO::WaitReadable
      # Rescue on no data in STDIN buffer.
    end

    # @return [Integer]
    def read
      value = @copy[@index]
      @index = (@index + 1) % 0x10
      value
    end

    # @param [Integer] value
    def write(value)
      if value[0] == 1
        @set = true
      elsif @set
        @set = false
        @copy = @buffer
        @buffer = 0
        @index = 0
      end
    end
  end
end

module Rnes
  class Ppu
    COLORS = [
      [0x52, 0x52, 0x52],
      [0x01, 0x1a, 0x51],
      [0x0f, 0x0f, 0x65],
      [0x23, 0x06, 0x63],
      [0x36, 0x03, 0x4b],
      [0x40, 0x04, 0x26],
      [0x3f, 0x09, 0x04],
      [0x32, 0x13, 0x00],
      [0x1f, 0x20, 0x00],
      [0x0b, 0x2a, 0x00],
      [0x00, 0x2f, 0x00],
      [0x00, 0x2e, 0x0a],
      [0x00, 0x26, 0x2d],
      [0x00, 0x00, 0x00],
      [0x00, 0x00, 0x00],
      [0x00, 0x00, 0x00],
      [0xa0, 0xa0, 0xa0],
      [0x1e, 0x4a, 0x9d],
      [0x38, 0x37, 0xbc],
      [0x58, 0x28, 0xb8],
      [0x75, 0x21, 0x94],
      [0x84, 0x23, 0x5c],
      [0x82, 0x2e, 0x24],
      [0x6f, 0x3f, 0x00],
      [0x51, 0x52, 0x00],
      [0x31, 0x63, 0x00],
      [0x1a, 0x6b, 0x05],
      [0x0e, 0x69, 0x2e],
      [0x10, 0x5c, 0x68],
      [0x00, 0x00, 0x00],
      [0x00, 0x00, 0x00],
      [0x00, 0x00, 0x00],
      [0xfe, 0xff, 0xff],
      [0x69, 0x9e, 0xfc],
      [0x89, 0x87, 0xff],
      [0xae, 0x76, 0xff],
      [0xce, 0x6d, 0xf1],
      [0xe0, 0x70, 0xb2],
      [0xde, 0x7c, 0x70],
      [0xc8, 0x91, 0x3e],
      [0xa6, 0xa7, 0x25],
      [0x81, 0xba, 0x28],
      [0x63, 0xc4, 0x46],
      [0x54, 0xc1, 0x7d],
      [0x56, 0xb3, 0xc0],
      [0x3c, 0x3c, 0x3c],
      [0x00, 0x00, 0x00],
      [0x00, 0x00, 0x00],
      [0xfe, 0xff, 0xff],
      [0xbe, 0xd6, 0xfd],
      [0xcc, 0xcc, 0xff],
      [0xdd, 0xc4, 0xff],
      [0xea, 0xc0, 0xf9],
      [0xf2, 0xc1, 0xdf],
      [0xf1, 0xc7, 0xc2],
      [0xe8, 0xd0, 0xaa],
      [0xd9, 0xda, 0x9d],
      [0xc9, 0xe2, 0x9e],
      [0xbc, 0xe6, 0xae],
      [0xb4, 0xe5, 0xc7],
      [0xb5, 0xdf, 0xe4],
      [0xa9, 0xa9, 0xa9],
      [0x00, 0x00, 0x00],
      [0x00, 0x00, 0x00],
    ].freeze
  end
end

module Rnes
  class PpuRegisters
    STATUS_IN_V_BLANK_BIT_INDEX = 7
    STATUS_SPRITE_HIT_BIT_INDEX = 6
    STATUS_OVERFLOW_BIT_INDEX = 5

    # @param [Integer]
    # @return [Integer]
    attr_accessor :control

    # @param [Integer]
    # @return [Integer]
    attr_accessor :mask

    # @return [Integer]
    attr_accessor :sprite_ram_address

    # @return [Integer]
    attr_reader :scroll_x

    # @return [Integer]
    attr_reader :scroll_y

    # @return [Integer]
    attr_reader :video_ram_address

    # @param [Integer]
    attr_writer :status

    def initialize
      @control = 0x0
      @mask = 0x0
      @status = 0x0

      @scroll_x = 0x0
      @scroll_y = 0x0

      @sprite_ram_address = 0x00
      @video_ram_address = 0x0000

      @buffer = 0x00
      @latch = false
    end

    # @return [Boolean]
    def background_enabled?
      @mask[3] == 1
    end

    # @return [Boolean]
    def background_pattern_table_address_banked?
      @control[4] == 1
    end

    # +------------+------------|
    # | 0 (0x2000) | 1 (0x2400) |
    # +------------+------------|
    # | 2 (0x2800) | 3 (0x2C00) |
    # +------------+------------|
    # @return [Integer] An integer from 0 to 3.
    def base_name_table_id
      @control & 0b11
    end

    # @return [Boolean]
    def color_blue_emphasized?
      @mask[7] == 1
    end

    # @return [Boolean]
    def color_green_emphasized?
      @mask[6] == 1
    end

    # @return [Boolean]
    def color_red_emphasized?
      @mask[5] == 1
    end

    # @return [Boolean]
    def color_greyscaled?
      @mask[0] == 1
    end

    # @return [Boolean]
    def has_v_blank_irq_enabled_bit?
      @control[7] == 1
    end

    # @return [Boolean]
    def horizontal_increment?
      @control[2] == 1
    end

    # @return [Boolean]
    def in_v_blank?
      @status[STATUS_IN_V_BLANK_BIT_INDEX] == 1
    end

    # @param [Boolean] boolean
    def in_v_blank=(boolean)
      toggle_status_bit(STATUS_IN_V_BLANK_BIT_INDEX, boolean)
    end

    # @param [Integer] offset
    def increment_video_ram_address(offset)
      @video_ram_address += offset
    end

    # @return [Boolean]
    def leftmost_background_shown?
      @mask[1] == 1
    end

    # @return [Boolean]
    def leftmost_sprite_shown?
      @mask[2] == 1
    end

    # @param [Boolean] boolean
    def overflow=(boolean)
      toggle_status_bit(STATUS_OVERFLOW_BIT_INDEX, boolean)
    end

    # @param [Integer] value
    def scroll=(value)
      if @latch
        @scroll_x = @buffer
        @scroll_y = value
      else
        @buffer = value
      end
      toggle_latch
    end

    # @return [Boolean]
    def sprite_enabled?
      @mask[4] == 1
    end

    # @return [Boolean]
    def sprite_hit?
      @status[STATUS_SPRITE_HIT_BIT_INDEX] == STATUS_SPRITE_HIT_BIT_INDEX
    end

    # @param [Boolean] boolean
    def sprite_hit=(boolean)
      toggle_status_bit(STATUS_SPRITE_HIT_BIT_INDEX, boolean)
    end

    # @return [Boolean]
    def sprite_pattern_table_address_banked?
      @control[3] == 1
    end

    # @return [Boolean]
    def sprite_size_doubled?
      @control[4] == 1
    end

    # @return [Integer]
    def status
      value = @status
      self.in_v_blank = false
      @latch = false
      value
    end

    # @param [Integer] value
    def video_ram_address=(value)
      if @latch
        @video_ram_address = value + (@buffer << 8)
      else
        @buffer = value
      end
      toggle_latch
    end

    private

    def toggle_latch
      @latch = !@latch
    end

    # @param [Integer] index
    # @param [Boolean] boolean
    def toggle_status_bit(index, boolean)
      if boolean
        @status |= 1 << index
      else
        @status &= ~(1 << index)
      end
    end
  end
end


module Rnes
  class PpuBus
    # @return [Rnes::Ram]
    attr_reader :character_ram

    # @param [Rnes::Ram] character_ram
    # @param [Rnes::Ram] video_ram
    def initialize(character_ram:, video_ram:)
      @character_ram = character_ram
      @video_ram = video_ram
    end

    # @param [Integer] address
    # @return [Integer]
    def read(address)
      case address
      when 0x0000..0x1FFF
        @character_ram.read(address)
      when 0x2000..0x27FF
        @video_ram.read(address - 0x2000)
      when 0x2800..0x2FFF
        read(address - 0x0800)
      when 0x3000..0x3EFF
        read(address - 0x1000)
      when 0x3F04, 0x3F08, 0x3F0C
        read(0x3F00)
      when 0x3F10, 0x3F14, 0x3F18, 0x3F1C
        read(address - 0x0010)
      when 0x3F00..0x3F1F
        @video_ram.read(address - 0x2000)
      when 0x3F20..0x3FFF
        read(address - 0x0020)
      when 0x4000..0xFFFF
        read(address - 0x4000)
      else
        raise ::Rnes::Errors::InvalidPpuBusAddressError, address
      end
    end

    # @param [Integer] address
    # @param [Integer] value
    def write(address, value)
      case address
      when 0x0000..0x1FFF
        @character_ram.write(address, value)
      when 0x2000..0x27FF
        @video_ram.write(address - 0x2000, value)
      when 0x2800..0x2FFF
        write(address - 0x0800, value)
      when 0x3000..0x3EFF
        write(address - 0x1000, value)
      when 0x3F10, 0x3F14, 0x3F18, 0x3F1C
        write(address - 0x0010, value)
      when 0x3F00..0x3F1F
        @video_ram.write(address - 0x2000, value)
      when 0x3F00..0x3FFF
        write(address - 0x0020, value)
      when 0x4000..0xFFFF
        write(address - 0x4000, value)
      else
        raise ::Rnes::Errors::InvalidPpuBusAddressError, address
      end
    end
  end
end

module Rnes
  class TerminalRenderer
    BRAILLE_BASE_CODE_POINT = 0x2800

    BRAILLE_HEIGHT = 4

    BRAILLE_WIDTH = 2

    BRIGHTNESS_SUM_THRESHOLD = 256

    TEXT_HEIGHT = 61

    TEXT_WIDTH = 128

    ESCAPE_TO_CLEAR_TEXT = "\e[#{TEXT_HEIGHT}A\e[#{TEXT_WIDTH}D".freeze

    def initialize
      @fps = 0
      @previous_fps = 0
    end

    def render(image)
      brailles = convert_image_to_string(image)
      fps_counter = "FPS:#{@previous_fps}"
      puts "#{ESCAPE_TO_CLEAR_TEXT}#{fps_counter}\n#{brailles}"
      second = ::Time.now.sec
      if @second == second
        @fps += 1
      else
        @previous_fps = @fps
        @fps = 0
        @second = second
      end
    end

    private

    # @return [String]
    def convert_image_to_string(image)
      0.step(image.height - 1, BRAILLE_HEIGHT).map do |y|
        0.step(image.width - 1, BRAILLE_WIDTH).map do |x|
          offset = [
            image.read(x: x + 0, y: y + 0),
            image.read(x: x + 0, y: y + 1),
            image.read(x: x + 0, y: y + 2),
            image.read(x: x + 1, y: y + 0),
            image.read(x: x + 1, y: y + 1),
            image.read(x: x + 1, y: y + 2),
            image.read(x: x + 0, y: y + 3),
            image.read(x: x + 1, y: y + 3),
          ].map.with_index do |rgb, i|
            (rgb.sum < BRIGHTNESS_SUM_THRESHOLD ? 0 : 1) << i
          end.reduce(:|)
          (BRAILLE_BASE_CODE_POINT + offset).chr('UTF-8')
        end.join
      end.join("\n")
    end
  end
end


module Rnes
  class Ppu
    ADDRESS_TO_FINISH_SPRITE_PALETTE_TABLE = 0x3F1F

    ADDRESS_TO_START_ATTRIBUTE_TABLE = 0x23C0

    ADDRESS_TO_START_NAME_TABLE = 0x2000

    ADDRESS_TO_START_BACKGROUND_PALETTE_TABLE = 0x3F00

    ADDRESS_TO_START_SPRITE_PALETTE_TABLE = 0x3F10

    BLOCK_HEIGHT = 16

    BLOCK_WIDTH = 16

    CYCLES_PER_LINE = 341

    PALETTE_ADDRESS_RANGE = (ADDRESS_TO_START_BACKGROUND_PALETTE_TABLE..ADDRESS_TO_FINISH_SPRITE_PALETTE_TABLE).freeze

    SPRITE_RAM_BYTESIZE = 2**8

    SPRITES_COUNT = 64

    TILE_HEIGHT = 8

    TILE_WIDTH = 8

    V_BLANK_HEIGHT = 21

    WINDOW_HEIGHT = 240

    WINDOW_WIDTH = 256

    ENCODED_ATTRIBUTES_HEIGHT = BLOCK_HEIGHT * 2

    ENCODED_ATTRIBUTES_WIDTH = BLOCK_WIDTH * 2

    ENCODED_ATTRIBUTES_COUNT_IN_HORIZONTAL_LINE = WINDOW_WIDTH / ENCODED_ATTRIBUTES_WIDTH

    ENCODED_ATTRIBUTES_COUNT_IN_VERTICAL_LINE = 256 / ENCODED_ATTRIBUTES_HEIGHT

    TILES_COUNT_IN_HORIZONTAL_LINE = WINDOW_WIDTH / TILE_WIDTH

    TILES_COUNT_IN_VERTICAL_LINE = WINDOW_HEIGHT / TILE_HEIGHT

    TILES_COUNT_IN_WINDOW = TILES_COUNT_IN_HORIZONTAL_LINE * TILES_COUNT_IN_VERTICAL_LINE

    # @note For debug use.
    # @param [Integer]
    # @return [Integer]
    attr_accessor :cycle

    # @note For debug use.
    # @param [Integer]
    # @return [Integer]
    attr_accessor :line

    # @note For debug use.
    # @return [Array<Rnes::Image>]
    attr_reader :image

    # @note For debug use.
    # @return [Rnes::PpuRegisters]
    attr_reader :registers

    # @param [Rnes::PpuBus] bus
    # @param [Rnes::InterruptLine] interrupt_line
    # @param [Rnes::TerminalRenderer] renderer
    def initialize(bus:, interrupt_line:, renderer:)
      @bus = bus
      @cycle = 0
      @image = ::Rnes::Image.new(height: WINDOW_HEIGHT, width: WINDOW_WIDTH)
      @interrupt_line = interrupt_line
      @line = 0
      @registers = ::Rnes::PpuRegisters.new
      @renderer = renderer
      @sprite_ram = ::Rnes::Ram.new(bytesize: SPRITE_RAM_BYTESIZE)
      @video_ram_reading_buffer = 0x00
    end

    # @param [Integer] address
    # @return [Integer]
    def read(address)
      case address
      when 0x0000
        @registers.control
      when 0x0001
        @registers.mask
      when 0x0002
        @registers.status
      when 0x0004
        read_from_sprite_ram(@registers.sprite_ram_address)
      when 0x0007
        read_from_video_ram_for_cpu
      else
        raise ::Rnes::Errors::InvalidPpuAddressError, address
      end
    end

    def step
      if on_visible_cycle? && x_in_tile.zero?
        draw_background_8pixels
      end
      if on_right_end_cycle?
        self.cycle = 0
        if on_bottom_end_line?
          self.line = 0
          deassert_nmi
          clear_sprite_hit
          clear_v_blank
          draw_sprites
          render_image
        else
          self.line += 1
          check_sprite_hit
          if on_line_to_start_v_blank?
            set_v_blank
            if v_blank_interrupt_enabled?
              assert_nmi
            end
          end
        end
      else
        self.cycle += 1
      end
    end

    # @param [Integer] index
    # @param [Integer] value
    def transfer_sprite_data(index:, value:)
      address = (@registers.sprite_ram_address + index) % SPRITE_RAM_BYTESIZE
      @sprite_ram.write(address, value)
    end

    # @param [Integer] address
    # @param [Integer] value
    # @return [Integer]
    def write(address, value)
      case address
      when 0x0000
        @registers.control = value
      when 0x0001
        @registers.mask = value
      when 0x0003
        @registers.sprite_ram_address = value
      when 0x0004
        write_to_sprite_ram_for_cpu(value)
      when 0x0005
        @registers.scroll = value
      when 0x0006
        @registers.video_ram_address = value
      when 0x0007
        write_to_video_ram_for_cpu(value)
      else
        raise ::Rnes::Errors::InvalidPpuAddressError, address
      end
    end

    private

    def assert_nmi
      @interrupt_line.assert_nmi
    end

    # @return [Integer]
    def base_name_table_address
      ADDRESS_TO_START_NAME_TABLE + @registers.base_name_table_id * 0x400
    end

    # @return [Integer]
    def base_background_pattern_table_address
      if registers.background_pattern_table_address_banked?
        0x1000
      else
        0x0000
      end
    end

    # @return [Integer]
    def base_sprite_pattern_table_address
      if registers.sprite_pattern_table_address_banked?
        0x1000
      else
        0x0000
      end
    end

    # +---+---+
    # | 0 | 1 |
    # +---+---+
    # | 2 | 3 |
    # +---+---+
    # @return [Integer] Integer from 0 to 3.
    def block_id_in_encoded_attributes
      (x_of_block.even? ? 0 : 1) + (y_of_block.even? ? 0 : 2)
    end

    def check_sprite_hit
      if read_from_sprite_ram(0) == y && @registers.background_enabled? && @registers.sprite_enabled?
        registers.sprite_hit = true
      end
    end

    def clear_sprite_hit
      registers.sprite_hit = false
    end

    def clear_v_blank
      registers.in_v_blank = false
    end

    def deassert_nmi
      @interrupt_line.deassert_nmi
    end

    def draw_background_8pixels
      pattern_index = read_pattern_index(background_pattern_index)
      pattern_line_low_byte_address = TILE_HEIGHT * 2 * pattern_index + y_in_tile
      pattern_line_low_byte = read_background_pattern_line(pattern_line_low_byte_address)
      pattern_line_high_byte = read_background_pattern_line(pattern_line_low_byte_address + TILE_HEIGHT)

      palette_ids_byte = read_object_attribute(object_attribute_index)
      palette_id = (palette_ids_byte >> (block_id_in_encoded_attributes * 2)) & 0b11

      TILE_WIDTH.times do |x_in_pattern|
        index_in_pattern_line_byte = TILE_WIDTH - 1 - x_in_pattern
        background_palette_index = pattern_line_low_byte[index_in_pattern_line_byte] | (pattern_line_high_byte[index_in_pattern_line_byte] << 1) | (palette_id << 2)
        color_id = read_color_id(background_palette_index)
        @image.write(
          value: ::Rnes::Ppu::COLORS[color_id],
          x: x + x_in_pattern,
          y: y,
        )
      end
    end

    # @note
    #   struct Sprite {
    #     U8 y;
    #     U8 tile;
    #     U8 attr;
    #     U8 x;
    #   }
    #
    # attr 76543210
    #      |||   `+- palette
    #      ||`------ priority (0: front, 1: back)
    #      |`------- horizontal flip
    #      `-------- vertical flip
    def draw_sprites
      0.step(SPRITES_COUNT - 1, 4) do |base_sprite_ram_address|
        y_for_sprite = read_from_sprite_ram(base_sprite_ram_address)
        pattern_index = read_from_sprite_ram(base_sprite_ram_address + 1)
        sprite_attribute_byte = read_from_sprite_ram(base_sprite_ram_address + 2)
        x_for_sprite = read_from_sprite_ram(base_sprite_ram_address + 3)

        palette_id = sprite_attribute_byte & 0b11
        reversed_horizontally = sprite_attribute_byte[6] == 1
        reversed_vertically = sprite_attribute_byte[7] == 1

        TILE_HEIGHT.times do |y_in_pattern|
          pattern_line_low_byte_address = TILE_HEIGHT * 2 * pattern_index + y_in_pattern
          pattern_line_low_byte = read_sprite_pattern_line(pattern_line_low_byte_address)
          pattern_line_high_byte = read_sprite_pattern_line(pattern_line_low_byte_address + TILE_HEIGHT)
          TILE_WIDTH.times do |x_in_pattern|
            index_in_pattern_line_byte = TILE_WIDTH - 1 - x_in_pattern
            sprite_palette_index = pattern_line_low_byte[index_in_pattern_line_byte] | (pattern_line_high_byte[index_in_pattern_line_byte] << 1) | (palette_id << 2)
            if sprite_palette_index % 4 != 0
              color_id = read_color_id(sprite_palette_index)
              y_in_pattern = TILE_HEIGHT - 1 - y_in_pattern if reversed_vertically
              x_in_pattern = TILE_WIDTH - 1 - x_in_pattern if reversed_horizontally
              @image.write(
                value: ::Rnes::Ppu::COLORS[color_id],
                x: x_for_sprite + x_in_pattern,
                y: y_for_sprite + y_in_pattern,
              )
            end
          end
        end
      end
    end

    # @return [Integer] Integer from 0 to 63.
    def object_attribute_index
      (y_of_encoded_attributes % ENCODED_ATTRIBUTES_COUNT_IN_VERTICAL_LINE) * ENCODED_ATTRIBUTES_COUNT_IN_HORIZONTAL_LINE +
        x_of_encoded_attributes % ENCODED_ATTRIBUTES_COUNT_IN_HORIZONTAL_LINE +
        background_pattern_index_paging_offset
    end

    # @return [Boolean]
    def on_bottom_end_line?
      line == WINDOW_HEIGHT + V_BLANK_HEIGHT
    end

    # @return [Boolean]
    def on_line_to_start_v_blank?
      line == WINDOW_HEIGHT
    end

    # @return [Boolean]
    def on_right_end_cycle?
      cycle == CYCLES_PER_LINE - 1
    end

    # @return [Boolean]
    def on_visible_cycle?
      (0...WINDOW_WIDTH).cover?(x) && (0...WINDOW_HEIGHT).cover?(y)
    end

    # @return [Boolean]
    def palette_data_requested?
      PALETTE_ADDRESS_RANGE.cover?(@registers.video_ram_address % 0x4000)
    end

    # @param [Integer] index.
    # @return [Integer]
    def read_background_pattern_line(index)
      read_pattern_line(base_background_pattern_table_address + index)
    end

    # @param [Integer] index
    # @return [Integer]
    def read_color_id(index)
      @bus.read(ADDRESS_TO_START_BACKGROUND_PALETTE_TABLE + index)
    end

    # @param [Integer] address
    # @return [Integer]
    def read_from_sprite_ram(address)
      @sprite_ram.read(address)
    end

    # @return [Integer]
    def read_from_video_ram_for_cpu
      if palette_data_requested?
        value = @bus.read(@registers.video_ram_address)
        @video_ram_reading_buffer = @bus.read(@registers.video_ram_address - 0x1000)
      else
        value = @video_ram_reading_buffer
        @video_ram_reading_buffer = @bus.read(@registers.video_ram_address)
      end
      @registers.increment_video_ram_address(video_ram_address_offset)
      value
    end

    # @param [Integer] index
    # @return [Integer] 4-color-palette IDs of 4 blocks, as 8 bit data.
    def read_object_attribute(index)
      @bus.read(ADDRESS_TO_START_ATTRIBUTE_TABLE + index)
    end

    # @param [Integer] index
    # @return [Integer]
    def read_pattern_line(index)
      @bus.read(index)
    end

    # @param [Integer] index.
    # @return [Integer]
    def read_sprite_pattern_line(index)
      read_pattern_line(base_sprite_pattern_table_address + index)
    end

    # @param [Integer] index
    # @return [Integer]
    def read_pattern_index(index)
      @bus.read(base_name_table_address + index)
    end

    def render_image
      @renderer.render(@image)
    end

    def set_v_blank
      registers.in_v_blank = true
    end

    # +-----------+-----------+
    # | 0(0x0000) | 1(0x0400) |
    # +-----------+-----------+
    # | 2(0x0800) | 3(0x0C00) |
    # +-----------+-----------+
    # @return [Integer] Integer from 0x0000 to 0x0FC0.
    def background_pattern_index
      background_pattern_index_in_window + background_pattern_index_paging_offset
    end

    # @return [Integer] Integer from 0x0000 to 0x03C0.
    def background_pattern_index_in_window
      (y_of_tile % TILES_COUNT_IN_VERTICAL_LINE) * TILES_COUNT_IN_HORIZONTAL_LINE + x_of_tile % TILES_COUNT_IN_HORIZONTAL_LINE
    end

    # @return [Integer] Integer from 0 to 3.
    def background_pattern_index_page
      x_of_tile / TILES_COUNT_IN_HORIZONTAL_LINE + y_of_tile / TILES_COUNT_IN_VERTICAL_LINE * 2
    end

    # @return [Integer] 0x0000, 0x0400, 0x0800, or 0x0C00.
    def background_pattern_index_paging_offset
      background_pattern_index_page * 0x0400
    end

    # @return [Boolean]
    def v_blank_interrupt_enabled?
      @registers.has_v_blank_irq_enabled_bit?
    end

    # @return [Integer]
    def video_ram_address_offset
      if registers.horizontal_increment?
        TILES_COUNT_IN_HORIZONTAL_LINE
      else
        1
      end
    end

    # @param [Integer] value
    def write_to_sprite_ram_for_cpu(value)
      @sprite_ram.write(@registers.sprite_ram_address, value)
      @registers.sprite_ram_address = (@registers.sprite_ram_address + 1) & 0xFF
    end

    # @param [Integer] value
    def write_to_video_ram_for_cpu(value)
      @bus.write(@registers.video_ram_address, value)
      @registers.increment_video_ram_address(video_ram_address_offset)
    end

    # @return [Integer]
    def x
      cycle - 1
    end

    # @return [Integer]
    def x_in_tile
      x_with_scroll % TILE_WIDTH
    end

    # @return [Integer]
    def x_of_block
      x_with_scroll / BLOCK_WIDTH
    end

    # @return [Integer]
    def x_of_encoded_attributes
      x_with_scroll / ENCODED_ATTRIBUTES_WIDTH
    end

    # @return [Integer]
    def x_of_tile
      x_with_scroll / TILE_WIDTH
    end

    # @return [Integer]
    def x_with_scroll
      x + @registers.scroll_x
    end

    # @return [Integer]
    def y
      line
    end

    # @return [Integer]
    def y_in_tile
      y_with_scroll % TILE_HEIGHT
    end

    # @return [Integer]
    def y_of_block
      y_with_scroll / BLOCK_HEIGHT
    end

    # @return [Integer]
    def y_of_encoded_attributes
      y_with_scroll / ENCODED_ATTRIBUTES_HEIGHT
    end

    # @return [Integer]
    def y_of_tile
      y_with_scroll / TILE_HEIGHT
    end

    # @return [Integer]
    def y_with_scroll
      y + @registers.scroll_y
    end
  end
end

module Rnes
  class CpuRegisters
    CARRY_BIT_INDEX = 0
    ZERO_BIT_INDEX = 1
    INTERRUPT_BIT_INDEX = 2
    DECIMAL_BIT_INDEX = 3
    BREAK_BIT_INDEX = 4
    RESERVED_BIT_INDEX = 5
    OVERFLOW_BIT_INDEX = 6
    NEGATIVE_BIT_INDEX = 7

    # @param [Integer]
    # @return [Integer]
    attr_accessor :accumulator

    # @param [Integer]
    # @return [Integer]
    attr_accessor :index_x

    # @param [Integer]
    # @return [Integer]
    attr_accessor :index_y

    # @param [Integer]
    # @return [Integer]
    attr_accessor :program_counter

    # @param [Integer]
    # @return [Integer]
    attr_accessor :stack_pointer

    # @param [Integer]
    # @return [Integer]
    attr_accessor :status

    def initialize
      @accumulator = 0x00
      @index_x = 0x00
      @index_y = 0x00
      @program_counter = 0x0000
      @stack_pointer = 0x0000
      @status = 0b00000000
    end

    # @return [Boolean]
    def break?
      @status[BREAK_BIT_INDEX] == 1
    end

    # @param [Boolean] boolean
    def break=(boolean)
      toggle_bit(BREAK_BIT_INDEX, boolean)
    end

    # @return [Boolean]
    def carry?
      @status[CARRY_BIT_INDEX] == 1
    end

    # @param [Boolean] boolean
    def carry=(boolean)
      toggle_bit(CARRY_BIT_INDEX, boolean)
    end

    # @return [Integer]
    def carry_bit
      @status[CARRY_BIT_INDEX]
    end

    # @return [Boolean]
    def decimal?
      @status[DECIMAL_BIT_INDEX] == 1
    end

    # @param [Boolean] boolean
    def decimal=(boolean)
      toggle_bit(DECIMAL_BIT_INDEX, boolean)
    end

    # @return [Boolean]
    def interrupt?
      @status[INTERRUPT_BIT_INDEX] == 1
    end

    # @param [Boolean] boolean
    def interrupt=(boolean)
      toggle_bit(INTERRUPT_BIT_INDEX, boolean)
    end

    # @return [Boolean]
    def negative?
      @status[NEGATIVE_BIT_INDEX] == 1
    end

    # @param [Boolean] boolean
    def negative=(boolean)
      toggle_bit(NEGATIVE_BIT_INDEX, boolean)
    end

    # @return [Boolean]
    def overflow?
      @status[OVERFLOW_BIT_INDEX] == 1
    end

    # @return [Boolean]
    def reserved?
      @status[RESERVED_BIT_INDEX] == 1
    end

    # @param [Boolean] boolean
    def reserved=(boolean)
      toggle_bit(RESERVED_BIT_INDEX, boolean)
    end

    def reset
      @accumulator = 0x00
      @index_x = 0x00
      @index_y = 0x00
      @program_counter = 0x0000
      @stack_pointer = 0x1FD
      @status = 0b00110100
    end

    # @param [Boolean] boolean
    def overflow=(boolean)
      toggle_bit(OVERFLOW_BIT_INDEX, boolean)
    end

    # @return [Boolean]
    def zero?
      @status[ZERO_BIT_INDEX] == 1
    end

    # @param [Boolean] boolean
    def zero=(boolean)
      toggle_bit(ZERO_BIT_INDEX, boolean)
    end

    private

    # @param [Integer] index
    # @param [Boolean] boolean
    def toggle_bit(index, boolean)
      if boolean
        @status |= 1 << index
      else
        @status &= ~(1 << index)
      end
    end
  end
end

module Rnes
  class Operation
    RECORDS = [
      {
        full_name: :BRK,
        name: :BRK,
        addressing_mode: :implied,
        cycle: 7,
      },
      {
        full_name: :ORA_INDX,
        name: :ORA,
        addressing_mode: :pre_indexed_indirect,
        cycle: 6,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :SLO_INDX,
        name: :SLO,
        addressing_mode: :pre_indexed_indirect,
        cycle: 8,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 3,
      },
      {
        full_name: :ORA_ZERO,
        name: :ORA,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :ASL_ZERO,
        name: :ASL,
        addressing_mode: :zero_page,
        cycle: 5,
      },
      {
        full_name: :SLO_ZERO,
        name: :SLO,
        addressing_mode: :zero_page,
        cycle: 5,
      },
      {
        full_name: :PHP,
        name: :PHP,
        addressing_mode: :implied,
        cycle: 3,
      },
      {
        full_name: :ORA_IMM,
        name: :ORA,
        addressing_mode: :immediate,
        cycle: 2,
      },
      {
        full_name: :ASL,
        name: :ASL,
        addressing_mode: :accumulator,
        cycle: 2,
      },
      {},
      {
        full_name: :NOPI,
        name: :NOPI,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :ORA_ABS,
        name: :ORA,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :ASL_ABS,
        name: :ASL,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :SLO_ABS,
        name: :SLO,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :BPL,
        name: :BPL,
        addressing_mode: :relative,
        cycle: 2,
      },
      {
        full_name: :ORA_INDY,
        name: :ORA,
        addressing_mode: :post_indexed_indirect,
        cycle: 5,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :SLO_INDY,
        name: :SLO,
        addressing_mode: :post_indexed_indirect,
        cycle: 8,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :ORA_ZEROX,
        name: :ORA,
        addressing_mode: :zero_page_x,
        cycle: 4,
      },
      {
        full_name: :ASL_ZEROX,
        name: :ASL,
        addressing_mode: :zero_page_x,
        cycle: 6,
      },
      {
        full_name: :SLO_ZEROX,
        name: :SLO,
        addressing_mode: :zero_page_x,
        cycle: 6,
      },
      {
        full_name: :CLC,
        name: :CLC,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :ORA_ABSY,
        name: :ORA,
        addressing_mode: :absolute_y,
        cycle: 4,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :SLO_ABSY,
        name: :SLO,
        addressing_mode: :absolute_y,
        cycle: 7,
      },
      {
        full_name: :NOPI,
        name: :NOPI,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :ORA_ABSX,
        name: :ORA,
        addressing_mode: :absolute_x,
        cycle: 4,
      },
      {
        full_name: :ASL_ABSX,
        name: :ASL,
        addressing_mode: :absolute_x,
        cycle: 6,
      },
      {
        full_name: :SLO_ABSX,
        name: :SLO,
        addressing_mode: :absolute_x,
        cycle: 7,
      },
      {
        full_name: :JSR_ABS,
        name: :JSR,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :AND_INDX,
        name: :AND,
        addressing_mode: :pre_indexed_indirect,
        cycle: 6,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :RLA_INDX,
        name: :RLA,
        addressing_mode: :pre_indexed_indirect,
        cycle: 8,
      },
      {
        full_name: :BIT_ZERO,
        name: :BIT,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :AND_ZERO,
        name: :AND,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :ROL_ZERO,
        name: :ROL,
        addressing_mode: :zero_page,
        cycle: 5,
      },
      {
        full_name: :RLA_ZERO,
        name: :RLA,
        addressing_mode: :zero_page,
        cycle: 5,
      },
      {
        full_name: :PLP,
        name: :PLP,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :AND_IMM,
        name: :AND,
        addressing_mode: :immediate,
        cycle: 2,
      },
      {
        full_name: :ROL,
        name: :ROL,
        addressing_mode: :accumulator,
        cycle: 2,
      },
      {},
      {
        full_name: :BIT_ABS,
        name: :BIT,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :AND_ABS,
        name: :AND,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :ROL_ABS,
        name: :ROL,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :RLA_ABS,
        name: :RLA,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :BMI,
        name: :BMI,
        addressing_mode: :relative,
        cycle: 2,
      },
      {
        full_name: :AND_INDY,
        name: :AND,
        addressing_mode: :post_indexed_indirect,
        cycle: 5,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :RLA_INDY,
        name: :RLA,
        addressing_mode: :post_indexed_indirect,
        cycle: 8,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :AND_ZEROX,
        name: :AND,
        addressing_mode: :zero_page_x,
        cycle: 4,
      },
      {
        full_name: :ROL_ZEROX,
        name: :ROL,
        addressing_mode: :zero_page_x,
        cycle: 6,
      },
      {
        full_name: :RLA_ZEROX,
        name: :RLA,
        addressing_mode: :zero_page_x,
        cycle: 6,
      },
      {
        full_name: :SEC,
        name: :SEC,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :AND_ABSY,
        name: :AND,
        addressing_mode: :absolute_y,
        cycle: 4,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :RLA_ABSY,
        name: :RLA,
        addressing_mode: :absolute_y,
        cycle: 7,
      },
      {
        full_name: :NOPI,
        name: :NOPI,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :AND_ABSX,
        name: :AND,
        addressing_mode: :absolute_x,
        cycle: 4,
      },
      {
        full_name: :ROL_ABSX,
        name: :ROL,
        addressing_mode: :absolute_x,
        cycle: 6,
      },
      {
        full_name: :RLA_ABSX,
        name: :RLA,
        addressing_mode: :absolute_x,
        cycle: 7,
      },
      {
        full_name: :RTI,
        name: :RTI,
        addressing_mode: :implied,
        cycle: 6,
      },
      {
        full_name: :EOR_INDX,
        name: :EOR,
        addressing_mode: :pre_indexed_indirect,
        cycle: 6,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :SRE_INDX,
        name: :SRE,
        addressing_mode: :pre_indexed_indirect,
        cycle: 8,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 3,
      },
      {
        full_name: :EOR_ZERO,
        name: :EOR,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :LSR_ZERO,
        name: :LSR,
        addressing_mode: :zero_page,
        cycle: 5,
      },
      {
        full_name: :SRE_ZERO,
        name: :SRE,
        addressing_mode: :zero_page,
        cycle: 5,
      },
      {
        full_name: :PHA,
        name: :PHA,
        addressing_mode: :implied,
        cycle: 3,
      },
      {
        full_name: :EOR_IMM,
        name: :EOR,
        addressing_mode: :immediate,
        cycle: 2,
      },
      {
        full_name: :LSR,
        name: :LSR,
        addressing_mode: :accumulator,
        cycle: 2,
      },
      {},
      {
        full_name: :JMP_ABS,
        name: :JMP,
        addressing_mode: :absolute,
        cycle: 3,
      },
      {
        full_name: :EOR_ABS,
        name: :EOR,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :LSR_ABS,
        name: :LSR,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :SRE_ABS,
        name: :SRE,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :BVC,
        name: :BVC,
        addressing_mode: :relative,
        cycle: 2,
      },
      {
        full_name: :EOR_INDY,
        name: :EOR,
        addressing_mode: :post_indexed_indirect,
        cycle: 5,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :SRE_INDY,
        name: :SRE,
        addressing_mode: :post_indexed_indirect,
        cycle: 8,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :EOR_ZEROX,
        name: :EOR,
        addressing_mode: :zero_page_x,
        cycle: 4,
      },
      {
        full_name: :LSR_ZEROX,
        name: :LSR,
        addressing_mode: :zero_page_x,
        cycle: 6,
      },
      {
        full_name: :SRE_ZEROX,
        name: :SRE,
        addressing_mode: :zero_page_x,
        cycle: 6,
      },
      {
        full_name: :CLI,
        name: :CLI,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :EOR_ABSY,
        name: :EOR,
        addressing_mode: :absolute_y,
        cycle: 4,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :SRE_ABSY,
        name: :SRE,
        addressing_mode: :absolute_y,
        cycle: 7,
      },
      {
        full_name: :NOPI,
        name: :NOPI,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :EOR_ABSX,
        name: :EOR,
        addressing_mode: :absolute_x,
        cycle: 4,
      },
      {
        full_name: :LSR_ABSX,
        name: :LSR,
        addressing_mode: :absolute_x,
        cycle: 6,
      },
      {
        full_name: :SRE_ABSX,
        name: :SRE,
        addressing_mode: :absolute_x,
        cycle: 7,
      },
      {
        full_name: :RTS,
        name: :RTS,
        addressing_mode: :implied,
        cycle: 6,
      },
      {
        full_name: :ADC_INDX,
        name: :ADC,
        addressing_mode: :pre_indexed_indirect,
        cycle: 6,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :RRA_INDX,
        name: :RRA,
        addressing_mode: :pre_indexed_indirect,
        cycle: 8,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 3,
      },
      {
        full_name: :ADC_ZERO,
        name: :ADC,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :ROR_ZERO,
        name: :ROR,
        addressing_mode: :zero_page,
        cycle: 5,
      },
      {
        full_name: :RRA_ZERO,
        name: :RRA,
        addressing_mode: :zero_page,
        cycle: 5,
      },
      {
        full_name: :PLA,
        name: :PLA,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :ADC_IMM,
        name: :ADC,
        addressing_mode: :immediate,
        cycle: 2,
      },
      {
        full_name: :ROR,
        name: :ROR,
        addressing_mode: :accumulator,
        cycle: 2,
      },
      {},
      {
        full_name: :JMP_INDABS,
        name: :JMP,
        addressing_mode: :indirect_absolute,
        cycle: 5,
      },
      {
        full_name: :ADC_ABS,
        name: :ADC,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :ROR_ABS,
        name: :ROR,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :RRA_ABS,
        name: :RRA,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :BVS,
        name: :BVS,
        addressing_mode: :relative,
        cycle: 2,
      },
      {
        full_name: :ADC_INDY,
        name: :ADC,
        addressing_mode: :post_indexed_indirect,
        cycle: 5,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :RRA_INDY,
        name: :RRA,
        addressing_mode: :post_indexed_indirect,
        cycle: 8,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :ADC_ZEROX,
        name: :ADC,
        addressing_mode: :zero_page_x,
        cycle: 4,
      },
      {
        full_name: :ROR_ZEROX,
        name: :ROR,
        addressing_mode: :zero_page_x,
        cycle: 6,
      },
      {
        full_name: :RRA_ZEROX,
        name: :RRA,
        addressing_mode: :zero_page_x,
        cycle: 6,
      },
      {
        full_name: :SEI,
        name: :SEI,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :ADC_ABSY,
        name: :ADC,
        addressing_mode: :absolute_y,
        cycle: 4,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :RRA_ABSY,
        name: :RRA,
        addressing_mode: :absolute_y,
        cycle: 7,
      },
      {
        full_name: :NOPI,
        name: :NOPI,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :ADC_ABSX,
        name: :ADC,
        addressing_mode: :absolute_x,
        cycle: 4,
      },
      {
        full_name: :ROR_ABSX,
        name: :ROR,
        addressing_mode: :absolute_x,
        cycle: 6,
      },
      {
        full_name: :RRA_ABSX,
        name: :RRA,
        addressing_mode: :absolute_x,
        cycle: 7,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :STA_INDX,
        name: :STA,
        addressing_mode: :pre_indexed_indirect,
        cycle: 6,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :SAX_INDX,
        name: :SAX,
        addressing_mode: :pre_indexed_indirect,
        cycle: 6,
      },
      {
        full_name: :STY_ZERO,
        name: :STY,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :STA_ZERO,
        name: :STA,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :STX_ZERO,
        name: :STX,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :SAX_ZERO,
        name: :SAX,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :DEY,
        name: :DEY,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :TXA,
        name: :TXA,
        addressing_mode: :implied,
        cycle: 2,
      },
      {},
      {
        full_name: :STY_ABS,
        name: :STY,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :STA_ABS,
        name: :STA,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :STX_ABS,
        name: :STX,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :SAX_ABS,
        name: :SAX,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :BCC,
        name: :BCC,
        addressing_mode: :relative,
        cycle: 2,
      },
      {
        full_name: :STA_INDY,
        name: :STA,
        addressing_mode: :post_indexed_indirect,
        cycle: 6,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {},
      {
        full_name: :STY_ZEROX,
        name: :STY,
        addressing_mode: :zero_page_x,
        cycle: 4,
      },
      {
        full_name: :STA_ZEROX,
        name: :STA,
        addressing_mode: :zero_page_x,
        cycle: 4,
      },
      {
        full_name: :STX_ZEROY,
        name: :STX,
        addressing_mode: :zero_page_y,
        cycle: 4,
      },
      {
        full_name: :SAX_ZEROY,
        name: :SAX,
        addressing_mode: :zero_page_y,
        cycle: 4,
      },
      {
        full_name: :TYA,
        name: :TYA,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :STA_ABSY,
        name: :STA,
        addressing_mode: :absolute_y,
        cycle: 4,
      },
      {
        full_name: :TXS,
        name: :TXS,
        addressing_mode: :implied,
        cycle: 2,
      },
      {},
      {},
      {
        full_name: :STA_ABSX,
        name: :STA,
        addressing_mode: :absolute_x,
        cycle: 4,
      },
      {},
      {},
      {
        full_name: :LDY_IMM,
        name: :LDY,
        addressing_mode: :immediate,
        cycle: 2,
      },
      {
        full_name: :LDA_INDX,
        name: :LDA,
        addressing_mode: :pre_indexed_indirect,
        cycle: 6,
      },
      {
        full_name: :LDX_IMM,
        name: :LDX,
        addressing_mode: :immediate,
        cycle: 2,
      },
      {
        full_name: :LAX_INDX,
        name: :LAX,
        addressing_mode: :pre_indexed_indirect,
        cycle: 6,
      },
      {
        full_name: :LDY_ZERO,
        name: :LDY,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :LDA_ZERO,
        name: :LDA,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :LDX_ZERO,
        name: :LDX,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :LAX_ZERO,
        name: :LAX,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :TAY,
        name: :TAY,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :LDA_IMM,
        name: :LDA,
        addressing_mode: :immediate,
        cycle: 2,
      },
      {
        full_name: :TAX,
        name: :TAX,
        addressing_mode: :implied,
        cycle: 2,
      },
      {},
      {
        full_name: :LDY_ABS,
        name: :LDY,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :LDA_ABS,
        name: :LDA,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :LDX_ABS,
        name: :LDX,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :LAX_ABS,
        name: :LAX,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :BCS,
        name: :BCS,
        addressing_mode: :relative,
        cycle: 2,
      },
      {
        full_name: :LDA_INDY,
        name: :LDA,
        addressing_mode: :post_indexed_indirect,
        cycle: 5,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :LAX_INDY,
        name: :LAX,
        addressing_mode: :post_indexed_indirect,
        cycle: 5,
      },
      {
        full_name: :LDY_ZEROX,
        name: :LDY,
        addressing_mode: :zero_page_x,
        cycle: 4,
      },
      {
        full_name: :LDA_ZEROX,
        name: :LDA,
        addressing_mode: :zero_page_x,
        cycle: 4,
      },
      {
        full_name: :LDX_ZEROY,
        name: :LDX,
        addressing_mode: :zero_page_y,
        cycle: 4,
      },
      {
        full_name: :LAX_ZEROY,
        name: :LAX,
        addressing_mode: :zero_page_y,
        cycle: 4,
      },
      {
        full_name: :CLV,
        name: :CLV,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :LDA_ABSY,
        name: :LDA,
        addressing_mode: :absolute_y,
        cycle: 4,
      },
      {
        full_name: :TSX,
        name: :TSX,
        addressing_mode: :implied,
        cycle: 2,
      },
      {},
      {
        full_name: :LDY_ABSX,
        name: :LDY,
        addressing_mode: :absolute_x,
        cycle: 4,
      },
      {
        full_name: :LDA_ABSX,
        name: :LDA,
        addressing_mode: :absolute_x,
        cycle: 4,
      },
      {
        full_name: :LDX_ABSY,
        name: :LDX,
        addressing_mode: :absolute_y,
        cycle: 4,
      },
      {
        full_name: :LAX_ABSY,
        name: :LAX,
        addressing_mode: :absolute_y,
        cycle: 4,
      },
      {
        full_name: :CPY_IMM,
        name: :CPY,
        addressing_mode: :immediate,
        cycle: 2,
      },
      {
        full_name: :CMP_INDX,
        name: :CMP,
        addressing_mode: :pre_indexed_indirect,
        cycle: 6,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :DCP_INDX,
        name: :DCP,
        addressing_mode: :pre_indexed_indirect,
        cycle: 8,
      },
      {
        full_name: :CPY_ZERO,
        name: :CPY,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :CMP_ZERO,
        name: :CMP,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :DEC_ZERO,
        name: :DEC,
        addressing_mode: :zero_page,
        cycle: 5,
      },
      {
        full_name: :DCP_ZERO,
        name: :DCP,
        addressing_mode: :zero_page,
        cycle: 5,
      },
      {
        full_name: :INY,
        name: :INY,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :CMP_IMM,
        name: :CMP,
        addressing_mode: :immediate,
        cycle: 2,
      },
      {
        full_name: :DEX,
        name: :DEX,
        addressing_mode: :implied,
        cycle: 2,
      },
      {},
      {
        full_name: :CPY_ABS,
        name: :CPY,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :CMP_ABS,
        name: :CMP,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :DEC_ABS,
        name: :DEC,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :DCP_ABS,
        name: :DCP,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :BNE,
        name: :BNE,
        addressing_mode: :relative,
        cycle: 2,
      },
      {
        full_name: :CMP_INDY,
        name: :CMP,
        addressing_mode: :post_indexed_indirect,
        cycle: 5,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :DCP_INDY,
        name: :DCP,
        addressing_mode: :post_indexed_indirect,
        cycle: 8,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :CMP_ZEROX,
        name: :CMP,
        addressing_mode: :zero_page_x,
        cycle: 4,
      },
      {
        full_name: :DEC_ZEROX,
        name: :DEC,
        addressing_mode: :zero_page_x,
        cycle: 6,
      },
      {
        full_name: :DCP_ZEROX,
        name: :DCP,
        addressing_mode: :zero_page_x,
        cycle: 6,
      },
      {
        full_name: :CLD,
        name: :CLD,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :CMP_ABSY,
        name: :CMP,
        addressing_mode: :absolute_y,
        cycle: 4,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :DCP_ABSY,
        name: :DCP,
        addressing_mode: :absolute_y,
        cycle: 2,
      },
      {
        full_name: :NOPI,
        name: :NOPI,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :CMP_ABSX,
        name: :CMP,
        addressing_mode: :absolute_x,
        cycle: 4,
      },
      {
        full_name: :DEC_ABSX,
        name: :DEC,
        addressing_mode: :absolute_x,
        cycle: 7,
      },
      {
        full_name: :DCP_ABSX,
        name: :DCP,
        addressing_mode: :absolute_x,
        cycle: 7,
      },
      {
        full_name: :CPX_IMM,
        name: :CPX,
        addressing_mode: :immediate,
        cycle: 2,
      },
      {
        full_name: :SBC_INDX,
        name: :SBC,
        addressing_mode: :pre_indexed_indirect,
        cycle: 6,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 3,
      },
      {
        full_name: :ISB_INDX,
        name: :ISB,
        addressing_mode: :pre_indexed_indirect,
        cycle: 8,
      },
      {
        full_name: :CPX_ZERO,
        name: :CPX,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :SBC_ZERO,
        name: :SBC,
        addressing_mode: :zero_page,
        cycle: 3,
      },
      {
        full_name: :INC_ZERO,
        name: :INC,
        addressing_mode: :zero_page,
        cycle: 5,
      },
      {
        full_name: :ISB_ZERO,
        name: :ISB,
        addressing_mode: :zero_page,
        cycle: 5,
      },
      {
        full_name: :INX,
        name: :INX,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :SBC_IMM,
        name: :SBC,
        addressing_mode: :immediate,
        cycle: 2,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :SBC_IMM,
        name: :SBC,
        addressing_mode: :immediate,
        cycle: 2,
      },
      {
        full_name: :CPX_ABS,
        name: :CPX,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :SBC_ABS,
        name: :SBC,
        addressing_mode: :absolute,
        cycle: 4,
      },
      {
        full_name: :INC_ABS,
        name: :INC,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :ISB_ABS,
        name: :ISB,
        addressing_mode: :absolute,
        cycle: 6,
      },
      {
        full_name: :BEQ,
        name: :BEQ,
        addressing_mode: :relative,
        cycle: 2,
      },
      {
        full_name: :SBC_INDY,
        name: :SBC,
        addressing_mode: :post_indexed_indirect,
        cycle: 5,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :ISB_INDY,
        name: :ISB,
        addressing_mode: :post_indexed_indirect,
        cycle: 8,
      },
      {
        full_name: :NOPD,
        name: :NOPD,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :SBC_ZEROX,
        name: :SBC,
        addressing_mode: :zero_page_x,
        cycle: 4,
      },
      {
        full_name: :INC_ZEROX,
        name: :INC,
        addressing_mode: :zero_page_x,
        cycle: 6,
      },
      {
        full_name: :ISB_ZEROX,
        name: :ISB,
        addressing_mode: :zero_page_x,
        cycle: 6,
      },
      {
        full_name: :SED,
        name: :SED,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :SBC_ABSY,
        name: :SBC,
        addressing_mode: :absolute_y,
        cycle: 4,
      },
      {
        full_name: :NOP,
        name: :NOP,
        addressing_mode: :implied,
        cycle: 2,
      },
      {
        full_name: :ISB_ABSY,
        name: :ISB,
        addressing_mode: :absolute_y,
        cycle: 2,
      },
      {
        full_name: :NOPI,
        name: :NOPI,
        addressing_mode: :implied,
        cycle: 4,
      },
      {
        full_name: :SBC_ABSX,
        name: :SBC,
        addressing_mode: :absolute_x,
        cycle: 4,
      },
      {
        full_name: :INC_ABSX,
        name: :INC,
        addressing_mode: :absolute_x,
        cycle: 7,
      },
      {
        full_name: :ISB_ABSX,
        name: :ISB,
        addressing_mode: :absolute_x,
        cycle: 7,
      },
    ].freeze
  end
end


module Rnes
  class Operation
    class << self
      # @param [Integer] operation_code
      # @return [Rnes::Operation]
      def build(operation_code)
        record = ::Rnes::Operation::RECORDS[operation_code]
        if record
          new(record)
        else
          raise ::Rnes::InvalidOperationCodeError, "Invalid operation code: #{operation_code}"
        end
      end
    end

    # @return [Symbol]
    attr_reader :addressing_mode

    # @return [Integer]
    attr_reader :cycle

    # @return [Symbol]
    attr_reader :full_name

    # @return [Symbol]
    attr_reader :name

    # @param [Symbol] addressing_mode
    # @param [Integer] cycle
    # @param [Symbol] full_name
    # @param [Symbol] name
    def initialize(addressing_mode:, cycle:, full_name:, name:)
      @addressing_mode = addressing_mode
      @cycle = cycle
      @full_name = full_name
      @name = name
    end

    # @return [Hash]
    def to_hash
      {
        addressing_mode: addressing_mode,
        cycle: cycle,
        full_name: full_name,
        name: name,
      }
    end
  end
end


module Rnes
  class CpuBus
    # @param [Rnes::Rom]
    # @return [Rnes::Rom]
    attr_accessor :program_rom

    # @param [Rnes::DmaController] dma_controller
    # @param [Rnes::Keypad] keypad1
    # @param [Rnes::Keypad] keypad2
    # @param [Rnes::Ppu] ppu
    # @param [Rnes::Ram] ram
    def initialize(dma_controller:, keypad1:, keypad2:, ppu:, ram:)
      @dma_controller = dma_controller
      @keypad1 = keypad1
      @keypad2 = keypad2
      @ppu = ppu
      @ram = ram
    end

    # @param [Integer]
    # @return [Integer]
    def read(address)
      case address
      when 0x0000..0x07FF
        @ram.read(address)
      when 0x0800..0x1FFF
        @ram.read(address - 0x0800)
      when 0x2000..0x2007
        @ppu.read(address - 0x2000)
      when 0x2008..0x3FFF
        read(address - 0x0008)
      when 0x4016
        @keypad1.read
      when 0x4017
        @keypad2.read
      when 0x4000..0x401F
        0 # TODO: I/O port for APU, etc
      when 0x4020..0x5FFF
        0 # TODO: extended RAM on special mappers
      when 0x6000..0x7FFF
        0 # TODO: battery-backed-up RAM
      when 0x8000..0xBFFF
        try_to_read_program_rom(address - 0x8000)
      when 0xC000..0xFFFF
        try_to_read_program_rom(address - offset_on_reading_program_rom_higher_region)
      else
        raise ::Rnes::Errors::InvalidCpuBusAddressError, address
      end
    end

    # @param [Integer] address
    # @param [Integer] value
    def write(address, value)
      case address
      when 0x0000..0x07FF
        @ram.write(address, value)
      when 0x0800..0x1FFF
        @ram.write(address - 0x0800, value)
      when 0x2000..0x2007
        @ppu.write(address - 0x2000, value)
      when 0x2008..0x3FFF
        write(address - 0x0008, value)
      when 0x4014
        @dma_controller.request_transfer(address_hint: value)
      when 0x4016
        @keypad1.write(value)
      when 0x4017
        @keypad2.write(value)
      when 0x4000..0x401F
        # TODO: I/O port for APU, etc
      when 0x4020..0x5FFF
        # TODO: extended RAM on special mappers
      when 0x6000..0x7FFF
        # TODO: battery-backed-up RAM
      when 0x8000..0xFFFF
      else
        raise ::Rnes::Errors::InvalidCpuBusAddressError, address
      end
    end

    private

    # @return [Boolean]
    def attatched_to_large_program_rom?
      @program_rom.bytesize > 16 * 2**10
    end

    # @return [Integer]
    def offset_on_reading_program_rom_higher_region
      attatched_to_large_program_rom? ? 0x8000 : 0xC000
    end

    # @param [Integer] address
    def try_to_read_program_rom(address)
      if @program_rom
        @program_rom.read(address)
      else
        raise ::Rnes::Errors::ProgramRomNotConnectedError
      end
    end
  end
end

module Rnes
  class DmaController
    TRANSFER_BYTESIZE = 2**8

    # @param [Rnes::Ppu] ppu
    # @param [Rnes::Ram] working_ram
    def initialize(ppu:, working_ram:)
      @ppu = ppu
      @requested = false
      @working_ram = working_ram
    end

    def transfer_if_requested
      if @requested
        transfer
      end
    end

    # @param [Integer] address_hint
    def request_transfer(address_hint:)
      @requested = true
      @working_ram_address = address_hint << 8
    end

    private

    def transfer
      TRANSFER_BYTESIZE.times do |index|
        value = @working_ram.read(@working_ram_address + index)
        @ppu.transfer_sprite_data(index: index, value: value)
      end
      @requested = false
    end
  end
end


module Rnes
  class Cpu
    INTERRUPTION_VECTOR_FOR_IRQ_OR_BRK = 0xFFFE

    INTERRUPTION_VECTOR_FOR_NMI = 0xFFFA

    INTERRUPTION_VECTOR_FOR_RESET = 0xFFFC

    # @return [Rnes::CpuBus] bus
    attr_reader :bus

    # @return [Rnes::CpuRegisters]
    attr_reader :registers

    # @param [Rnes::CpuBus] bus
    # @param [Rnes::InterruptLine] interrupt_line
    def initialize(bus:, interrupt_line:)
      @branched = false
      @bus = bus
      @crossed = false
      @interrupt_line = interrupt_line
      @registers = ::Rnes::CpuRegisters.new
    end

    # @note For logging.
    # @return [Rnes::Operation]
    def read_operation
      address = @registers.program_counter
      operation_code = read(address)
      ::Rnes::Operation.build(operation_code)
    end

    def reset
      @registers.reset
      @registers.program_counter = read_word(INTERRUPTION_VECTOR_FOR_RESET)
    end

    # @return [Integer]
    def step
      handle_interrupts
      operation = fetch_operation
      operand = fetch_operand_by(operation.addressing_mode)
      execute_operation(
        addressing_mode: operation.addressing_mode,
        operand: operand,
        operation_name: operation.name,
      )
      cycles_count = operation.cycle + (@branched ? 1 : 0) + (@crossed ? 1 : 0)
      @branched = false
      @crossed = false
      cycles_count
    end

    private

    # @param [Integer] address
    def branch(address)
      @branched = true
      @registers.program_counter = address
    end

    # @param [Symbol] addressing_mode
    # @param [Integer, nil] operand
    # @param [Symbol] operation_name
    # @return [Integer]
    def execute_operation(addressing_mode:, operand:, operation_name:)
      case operation_name
      when :ADC
        if addressing_mode == :immediate
          execute_operation_adc_for_immediate_addressing(operand)
        else
          execute_operation_adc_for_non_immediate_addressing(operand)
        end
      when :AND
        if addressing_mode == :immediate
          execute_operation_and_for_immediate_addressing(operand)
        else
          execute_operation_and_for_non_immediate_addressing(operand)
        end
      when :ASL
        if addressing_mode == :accumulator
          execute_operation_asl_for_accoumulator(operand)
        else
          execute_operation_asl_for_non_accumulator(operand)
        end
      when :BCC
        execute_operation_bcc(operand)
      when :BCS
        execute_operation_bcs(operand)
      when :BEQ
        execute_operation_beq(operand)
      when :BIT
        execute_operation_bit(operand)
      when :BMI
        execute_operation_bmi(operand)
      when :BNE
        execute_operation_bne(operand)
      when :BPL
        execute_operation_bpl(operand)
      when :BRK
        execute_operation_brk(operand)
      when :BVC
        execute_operation_bvc(operand)
      when :BVS
        execute_operation_bvs(operand)
      when :CLC
        execute_operation_clc(operand)
      when :CLD
        execute_operation_cld(operand)
      when :CLI
        execute_operation_cli(operand)
      when :CLV
        execute_operation_clv(operand)
      when :CMP
        if addressing_mode == :immediate
          execute_operation_cmp_for_immediate_addressing(operand)
        else
          execute_operation_cmp_for_non_immediate_addressing(operand)
        end
      when :CPX
        if addressing_mode == :immediate
          execute_operation_cpx_for_immediate_addressing(operand)
        else
          execute_operation_cpx_for_non_immediate_addressing(operand)
        end
      when :CPY
        if addressing_mode == :immediate
          execute_operation_cpy_for_immediate_addressing(operand)
        else
          execute_operation_cpy_for_non_immediate_addressing(operand)
        end
      when :DCP
        execute_operation_dcp(operand)
      when :DEC
        execute_operation_dec(operand)
      when :DEX
        execute_operation_dex(operand)
      when :DEY
        execute_operation_dey(operand)
      when :EOR
        if addressing_mode == :immediate
          execute_operation_eor_for_immediate_addressing(operand)
        else
          execute_operation_eor_for_non_immediate_addressing(operand)
        end
      when :INC
        execute_operation_inc(operand)
      when :INX
        execute_operation_inx(operand)
      when :INY
        execute_operation_iny(operand)
      when :ISB
        execute_operation_isb(operand)
      when :JMP
        execute_operation_jmp(operand)
      when :JSR
        execute_operation_jsr(operand)
      when :LAX
        execute_operation_lax(operand)
      when :LDA
        if addressing_mode == :immediate
          execute_operation_lda_for_immediate_addressing(operand)
        else
          execute_operation_lda_for_non_immediate_addressing(operand)
        end
      when :LDX
        if addressing_mode == :immediate
          execute_operation_ldx_for_immediate_addressing(operand)
        else
          execute_operation_ldx_for_non_immediate_addressing(operand)
        end
      when :LDY
        if addressing_mode == :immediate
          execute_operation_ldy_for_immediate_addressing(operand)
        else
          execute_operation_ldy_for_non_immediate_addressing(operand)
        end
      when :LSR
        if addressing_mode == :accumulator
          execute_operation_lsr_for_accumulator(operand)
        else
          execute_operation_lsr_for_non_accumulator(operand)
        end
      when :NOP
        execute_operation_nop(operand)
      when :NOPD
        execute_operation_nopd(operand)
      when :NOPI
        execute_operation_nopi(operand)
      when :ORA
        if addressing_mode == :immediate
          execute_operation_ora_for_immediate_addressing(operand)
        else
          execute_operation_ora_for_non_immediate_addressing(operand)
        end
      when :PHA
        execute_operation_pha(operand)
      when :PHP
        execute_operation_php(operand)
      when :PLA
        execute_operation_pla(operand)
      when :PLP
        execute_operation_plp(operand)
      when :RLA
        execute_operation_rla(operand)
      when :ROL
        if addressing_mode == :accumulator
          execute_operation_rol_for_accumulator(operand)
        else
          execute_operation_rol_for_non_accumulator(operand)
        end
      when :ROR
        if addressing_mode == :accumulator
          execute_operation_ror_for_accumulator(operand)
        else
          execute_operation_ror_for_non_accumulator(operand)
        end
      when :RRA
        execute_operation_rra(operand)
      when :RTI
        execute_operation_rti(operand)
      when :RTS
        execute_operation_rts(operand)
      when :SAX
        execute_operation_sax(operand)
      when :SBC
        if addressing_mode == :immediate
          execute_operation_sbc_for_immediate_addressing(operand)
        else
          execute_operation_sbc_for_non_immediate_addressing(operand)
        end
      when :SEC
        execute_operation_sec(operand)
      when :SED
        execute_operation_sed(operand)
      when :SEI
        execute_operation_sei(operand)
      when :SLO
        execute_operation_slo(operand)
      when :SRE
        execute_operation_sre(operand)
      when :STA
        execute_operation_sta(operand)
      when :STX
        execute_operation_stx(operand)
      when :STY
        execute_operation_sty(operand)
      when :TAX
        execute_operation_tax(operand)
      when :TAY
        execute_operation_tay(operand)
      when :TSX
        execute_operation_tsx(operand)
      when :TXA
        execute_operation_txa(operand)
      when :TXS
        execute_operation_txs(operand)
      when :TYA
        execute_operation_tya(operand)
      else
        raise ::Rnes::Errors::InvalidOperationError, "Invalid operation: #{operation_name}"
      end
    end

    # @param [Integer] operand
    def execute_operation_adc_for_immediate_addressing(operand)
      result = operand + @registers.accumulator + @registers.carry_bit
      @registers.carry = result > 0xFF
      @registers.negative = result[7] == 1
      @registers.overflow = (@registers.accumulator ^ operand)[7].zero? && !(@registers.accumulator ^ result)[7].zero?
      @registers.zero = (result & 0xFF).zero?
      @registers.accumulator = result & 0xFF
    end

    # @param [Integer] operand
    def execute_operation_adc_for_non_immediate_addressing(operand)
      operand = read(operand)
      execute_operation_adc_for_immediate_addressing(operand)
    end

    # @param [Integer] operand
    def execute_operation_and_for_immediate_addressing(operand)
      result = operand & @registers.accumulator
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result
    end

    # @param [Integer] operand
    def execute_operation_and_for_non_immediate_addressing(operand)
      operand = read(operand)
      execute_operation_and_for_immediate_addressing(operand)
    end

    # @param [Integer] operand
    def execute_operation_asl_for_accoumulator(_operand)
      value = @registers.accumulator
      result = (value << 1) & 0xFF
      @registers.carry = value[7] == 1
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result
    end

    # @param [Integer] operand
    def execute_operation_asl_for_non_accumulator(operand)
      value = read(operand)
      result = (value << 1) & 0xFF
      @registers.carry = value[7] == 1
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      write(operand, result)
    end

    # @param [Integer] operand
    def execute_operation_bcc(operand)
      unless @registers.carry?
        branch(operand)
      end
    end

    # @param [Integer] operand
    def execute_operation_bcs(operand)
      if @registers.carry?
        branch(operand)
      end
    end

    # @param [Integer] operand
    def execute_operation_beq(operand)
      if @registers.zero?
        branch(operand)
      end
    end

    # @param [Integer] operand
    def execute_operation_bit(operand)
      result = read(operand)
      @registers.overflow = result[6] == 1
      @registers.negative = result[7] == 1
      @registers.zero = (@registers.accumulator & result).zero?
    end

    # @param [Integer] operand
    def execute_operation_bmi(operand)
      if @registers.negative?
        branch(operand)
      end
    end

    # @param [Integer] operand
    def execute_operation_bne(operand)
      unless @registers.zero?
        branch(operand)
      end
    end

    # @param [Integer] operand
    def execute_operation_bpl(operand)
      unless @registers.negative?
        branch(operand)
      end
    end

    # @param [Integer] operand
    def execute_operation_brk(_operand)
      @registers.break = true
      @registers.program_counter += 1
      push_word(@registers.program_counter)
      push(@registers.status)
      unless @registers.interrupt?
        @registers.interrupt = true
        @registers.program_counter = read_word(INTERRUPTION_VECTOR_FOR_IRQ_OR_BRK)
      end
      @registers.program_counter -= 1
    end

    # @param [Integer] operand
    def execute_operation_bvc(operand)
      unless @registers.overflow?
        branch(operand)
      end
    end

    # @param [Integer] operand
    def execute_operation_bvs(operand)
      if @registers.overflow?
        branch(operand)
      end
    end

    # @param [Integer] operand
    def execute_operation_clc(_operand)
      @registers.carry = false
    end

    # @param [Integer] operand
    def execute_operation_cld(_operand)
      @registers.decimal = false
    end

    # @param [Integer] operand
    def execute_operation_cli(_operand)
      @registers.interrupt = false
    end

    # @param [Integer] operand
    def execute_operation_clv(_operand)
      @registers.overflow = false
    end

    # @param [Integer] operand
    def execute_operation_cmp_for_immediate_addressing(operand)
      result = @registers.accumulator - operand
      @registers.carry = result >= 0
      @registers.negative = result[7] == 1
      @registers.zero = (result & 0xFF).zero?
    end

    # @param [Integer] operand
    def execute_operation_cmp_for_non_immediate_addressing(operand)
      operand = read(operand)
      execute_operation_cmp_for_immediate_addressing(operand)
    end

    # @param [Integer] operand
    def execute_operation_cpx_for_immediate_addressing(operand)
      result = @registers.index_x - operand
      @registers.carry = result >= 0
      @registers.negative = result[7] == 1
      @registers.zero = (result & 0xFF).zero?
    end

    # @param [Integer] operand
    def execute_operation_cpx_for_non_immediate_addressing(operand)
      operand = read(operand)
      execute_operation_cpx_for_immediate_addressing(operand)
    end

    # @param [Integer] operand
    def execute_operation_cpy_for_immediate_addressing(operand)
      result = @registers.index_y - operand
      @registers.carry = result >= 0
      @registers.negative = result[7] == 1
      @registers.zero = (result & 0xFF).zero?
    end

    # @param [Integer] operand
    def execute_operation_cpy_for_non_immediate_addressing(operand)
      operand = read(operand)
      execute_operation_cpy_for_immediate_addressing(operand)
    end

    # @param [Integer] operand
    def execute_operation_dcp(operand)
      result = (read(operand) - 1) & 0xFF
      sub_result = (@registers.accumulator - result) & 0x1FF
      @registers.negative = sub_result[7] == 1
      @registers.zero = sub_result.zero?
      write(operand, result)
    end

    # @param [Integer] operand
    def execute_operation_dec(operand)
      result = (read(operand) - 1) & 0xFF
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      write(operand, result)
    end

    # @param [Integer] operand
    def execute_operation_dex(_operand)
      result = (@registers.index_x - 1) & 0xFF
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.index_x = result
    end

    # @param [Integer] operand
    def execute_operation_dey(_operand)
      result = (@registers.index_y - 1) & 0xFF
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.index_y = result
    end

    # @param [Integer] operand
    def execute_operation_eor_for_immediate_addressing(operand)
      result = (operand ^ @registers.accumulator) & 0xFF
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result
    end

    # @param [Integer] operand
    def execute_operation_eor_for_non_immediate_addressing(operand)
      operand = read(operand)
      execute_operation_eor_for_immediate_addressing(operand)
    end

    # @param [Integer] operand
    def execute_operation_inc(operand)
      result = (read(operand) + 1) & 0xFF
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      write(operand, result)
    end

    # @param [Integer] operand
    def execute_operation_inx(_operand)
      result = (@registers.index_x + 1) & 0xFF
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.index_x = result
    end

    # @param [Integer] operand
    def execute_operation_iny(_operand)
      result = (@registers.index_y + 1) & 0xFF
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.index_y = result
    end

    # @param [Integer] operand
    def execute_operation_isb(operand)
      value = (read(operand) + 1) & 0xFF
      result = (~value & 0xFF) + @registers.accumulator + @registers.carry_bit
      @registers.overflow = (@registers.accumulator ^ value)[7].zero? && !(@registers.accumulator ^ result)[7].zero?
      @registers.carry = result > 0xFF
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result & 0xFF
      write(operand, value)
    end

    # @param [Integer] operand
    def execute_operation_jmp(operand)
      @registers.program_counter = operand
    end

    # @param [Integer] operand
    def execute_operation_jsr(operand)
      push_word(@registers.program_counter - 1)
      @registers.program_counter = operand
    end

    # @param [Integer] operand
    def execute_operation_lax(operand)
      result = read(operand)
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result
      @registers.index_x = result
    end

    # @param [Integer] operand
    def execute_operation_lda_for_immediate_addressing(operand)
      @registers.negative = operand[7] == 1
      @registers.zero = operand.zero?
      @registers.accumulator = operand
    end

    # @param [Integer] operand
    def execute_operation_lda_for_non_immediate_addressing(operand)
      operand = read(operand)
      execute_operation_lda_for_immediate_addressing(operand)
    end

    # @param [Integer] operand
    def execute_operation_ldx_for_immediate_addressing(operand)
      @registers.negative = operand[7] == 1
      @registers.zero = operand.zero?
      @registers.index_x = operand
    end

    # @param [Integer] operand
    def execute_operation_ldx_for_non_immediate_addressing(operand)
      operand = read(operand)
      execute_operation_ldx_for_immediate_addressing(operand)
    end

    # @param [Integer] operand
    def execute_operation_ldy_for_immediate_addressing(operand)
      @registers.negative = operand[7] == 1
      @registers.zero = operand.zero?
      @registers.index_y = operand
    end

    # @param [Integer] operand
    def execute_operation_ldy_for_non_immediate_addressing(operand)
      operand = read(operand)
      execute_operation_ldy_for_immediate_addressing(operand)
    end

    # @param [Integer] operand
    def execute_operation_lsr_for_accumulator(_operand)
      value = @registers.accumulator
      result = value >> 1
      @registers.carry = value[0] == 1
      @registers.negative = false
      @registers.zero = result.zero?
      @registers.accumulator = result
    end

    # @param [Integer] operand
    def execute_operation_lsr_for_non_accumulator(operand)
      value = read(operand)
      result = value >> 1
      @registers.carry = value[0] == 1
      @registers.negative = false
      @registers.zero = result.zero?
      write(operand, result)
    end

    # @param [Integer] operand
    def execute_operation_nop(operand)
    end

    # @param [Integer] operand
    def execute_operation_nopd(_operand)
      @registers.program_counter += 1
    end

    # @param [Integer] operand
    def execute_operation_nopi(_operand)
      @registers.program_counter += 2
    end

    # @param [Integer] operand
    def execute_operation_ora_for_immediate_addressing(operand)
      result = @registers.accumulator | operand
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result & 0xFF
    end

    # @param [Integer] operand
    def execute_operation_ora_for_non_immediate_addressing(operand)
      operand = read(operand)
      execute_operation_ora_for_immediate_addressing(operand)
    end

    # @param [Integer] operand
    def execute_operation_pha(_operand)
      push(@registers.accumulator)
    end

    # @param [Integer] operand
    def execute_operation_php(_operand)
      push(@registers.status | 0x10)
    end

    # @param [Integer] operand
    def execute_operation_pla(_operand)
      result = pop
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result
    end

    # @param [Integer] operand
    def execute_operation_plp(_operand)
      @registers.status = pop & 0b11101111
      @registers.reserved = true
    end

    # @param [Integer] operand
    def execute_operation_rla(operand)
      value = (read(operand) << 1) + @registers.carry_bit
      result = (value & @registers.accumulator) & 0xFF
      @registers.carry = value[8] == 1
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result
      write(operand, value & 0xFF)
    end

    # @param [Integer] operand
    def execute_operation_rol_for_accumulator(_operand)
      value = @registers.accumulator
      result = ((value << 1) | @registers.carry_bit) & 0xFF
      @registers.carry = value[7] == 1
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result
    end

    # @param [Integer] operand
    def execute_operation_rol_for_non_accumulator(operand)
      value = read(operand)
      result = ((value << 1) | @registers.carry_bit) & 0xFF
      @registers.carry = value[7] == 1
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      write(operand, result)
    end

    # @param [Integer] operand
    def execute_operation_ror_for_accumulator(_operand)
      value = @registers.accumulator
      result = ((value >> 1) | (@registers.carry_bit << 7))
      @registers.carry = value[0] == 1
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result
    end

    # @param [Integer] operand
    def execute_operation_ror_for_non_accumulator(operand)
      value = read(operand)
      result = ((value >> 1) | (@registers.carry_bit << 7))
      @registers.carry = value[0] == 1
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      write(operand, result)
    end

    # @param [Integer] operand
    def execute_operation_rra(operand)
      read_value = read(operand)
      value = (read_value >> 1) | (@registers.carry_bit << 7)
      result = value + @registers.accumulator + read_value[0]
      @registers.carry = result > 0xFF
      @registers.overflow = (@registers.accumulator ^ value)[7].zero? && !(@registers.accumulator ^ result)[7].zero?
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result & 0xFF
      write(operand, value)
    end

    # @param [Integer] operand
    def execute_operation_rti(_operand)
      @registers.status = pop
      @registers.program_counter = pop_word
      @registers.reserved = true
    end

    # @param [Integer] operand
    def execute_operation_rts(_operand)
      @registers.program_counter = pop_word
      @registers.program_counter += 1
    end

    # @param [Integer] operand
    def execute_operation_sax(operand)
      result = @registers.accumulator & @registers.index_x
      write(operand, result)
    end

    # @param [Integer] operand
    def execute_operation_sbc_for_immediate_addressing(operand)
      result = @registers.accumulator - operand - 1 + @registers.carry_bit
      @registers.overflow = ((@registers.accumulator ^ result) & 0x80 != 0 && ((@registers.accumulator ^ operand) & 0x80) != 0)
      @registers.carry = result >= 0
      @registers.negative = result[7] == 1
      @registers.zero = (result & 0xFF).zero?
      @registers.accumulator = result & 0xFF
    end

    # @param [Integer] operand
    def execute_operation_sbc_for_non_immediate_addressing(operand)
      operand = read(operand)
      execute_operation_sbc_for_immediate_addressing(operand)
    end

    # @param [Integer] operand
    def execute_operation_sec(_operand)
      @registers.carry = true
    end

    # @param [Integer] operand
    def execute_operation_sed(_operand)
      @registers.decimal = true
    end

    # @param [Integer] operand
    def execute_operation_sei(_operand)
      @registers.interrupt = true
    end

    # @param [Integer] operand
    def execute_operation_slo(operand)
      read_value = read(operand)
      value = (read_value << 1) & 0xFF
      result = value | @registers.accumulator
      @registers.carry = read_value[7] == 1
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result
      write(operand, value)
    end

    # @param [Integer] operand
    def execute_operation_sre(operand)
      read_value = read(operand)
      value = read_value >> 1
      result = value ^ @registers.accumulator
      @registers.carry = read_value[0] == 1
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result
      write(operand, value)
    end

    # @param [Integer] operand
    def execute_operation_sta(operand)
      write(operand, @registers.accumulator)
    end

    # @param [Integer] operand
    def execute_operation_stx(operand)
      write(operand, @registers.index_x)
    end

    # @param [Integer] operand
    def execute_operation_sty(operand)
      write(operand, @registers.index_y)
    end

    # @param [Integer] operand
    def execute_operation_tax(_operand)
      result = @registers.accumulator
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.index_x = result
    end

    # @param [Integer] operand
    def execute_operation_tay(_operand)
      result = @registers.accumulator
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.index_y = result
    end

    # @param [Integer] operand
    def execute_operation_tsx(_operand)
      result = @registers.stack_pointer & 0xFF
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.index_x = result
    end

    # @param [Integer] operand
    def execute_operation_txa(_operand)
      result = @registers.index_x
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result
    end

    # @param [Integer] operand
    def execute_operation_txs(_operand)
      @registers.stack_pointer = @registers.index_x + 0x100
    end

    # @param [Integer] operand
    def execute_operation_tya(_operand)
      result = @registers.index_y
      @registers.negative = result[7] == 1
      @registers.zero = result.zero?
      @registers.accumulator = result
    end

    # @return [Integer]
    def fetch
      address = @registers.program_counter
      value = read(address)
      @registers.program_counter += 1
      value
    end

    # @param [Symbol] addressing_mode
    def fetch_operand_by(addressing_mode)
      case addressing_mode
      when :absolute
        fetch_operand_by_absolute_addressing
      when :absolute_x
        fetch_operand_by_absolute_x_addressing
      when :absolute_y
        fetch_operand_by_absolute_y_addressing
      when :accumulator
        fetch_operand_by_accumulator_addressing
      when :immediate
        fetch_operand_by_immediate_addressing
      when :implied
        fetch_operand_by_implied_addressing
      when :indirect_absolute
        fetch_operand_by_indirect_absolute_addressing
      when :post_indexed_indirect
        fetch_operand_by_post_indexed_indirect_addressing
      when :pre_indexed_indirect
        fetch_operand_by_pre_indexed_indirect_addressing
      when :relative
        fetch_operand_by_relative_addressing
      when :zero_page
        fetch_operand_by_zero_page_addressing
      when :zero_page_x
        fetch_operand_by_zero_page_x_addressing
      when :zero_page_y
        fetch_operand_by_zero_page_y_addressing
      else
        raise ::Rnes::Errors::InvalidAddressingModeError, "Invalid addressing mode: #{addressing_mode}"
      end
    end

    # @return [Integer]
    def fetch_operand_by_absolute_addressing
      fetch_word
    end

    # @return [Integer]
    def fetch_operand_by_absolute_x_addressing
      base_address = fetch_word
      @crossed = (base_address & 0xFF00) != ((base_address + @registers.index_x) & 0xFF00)
      (base_address + @registers.index_x) & 0xFFFF
    end

    # @return [Integer]
    def fetch_operand_by_absolute_y_addressing
      base_address = fetch_word
      @crossed = (base_address & 0xFF00) != ((base_address + @registers.index_y) & 0xFF00)
      (base_address + @registers.index_y) & 0xFFFF
    end

    # @return [nil]
    def fetch_operand_by_accumulator_addressing
    end

    # @return [Integer]
    def fetch_operand_by_immediate_addressing
      fetch
    end

    # @return [nil]
    def fetch_operand_by_implied_addressing
    end

    # @note The address must not overlap a page boundary as a bug in the original 6502 prevents it from being fetched properly.
    # @return [Integer]
    def fetch_operand_by_indirect_absolute_addressing
      address = fetch_word
      low = read(address)
      high = read((address & 0xFF00) | ((address + 1) & 0xFF))
      low + (high << 8)
    end

    # @return [Integer]
    def fetch_operand_by_pre_indexed_indirect_addressing
      base_address = (fetch + @registers.index_x) & 0xFF
      address = read_word_with_wrap_around(base_address)
      @crossed = (address & 0xFF00) != (base_address & 0xFF00)
      address
    end

    # @return [Integer]
    def fetch_operand_by_post_indexed_indirect_addressing
      base_address = fetch
      address = (read_word_with_wrap_around(base_address) + @registers.index_y) & 0xFFFF
      @crossed = (address & 0xFF00) != (base_address & 0xFF00)
      address
    end

    # @return [Integer]
    def fetch_operand_by_relative_addressing
      int8 = fetch
      offset = int8 >= 0x80 ? int8 - 256 : int8
      address = @registers.program_counter + offset
      @crossed = (address & 0xFF00) != (@registers.program_counter & 0xFF00)
      address
    end

    # @return [Integer]
    def fetch_operand_by_zero_page_addressing
      fetch
    end

    # @return [Integer]
    def fetch_operand_by_zero_page_x_addressing
      (fetch + @registers.index_x) & 0xFF
    end

    # @return [Integer]
    def fetch_operand_by_zero_page_y_addressing
      (fetch + @registers.index_y) & 0xFF
    end

    # @return [Rnes::Operation]
    def fetch_operation
      operation_code = fetch
      ::Rnes::Operation.build(operation_code)
    end

    # @return [Integer]
    def fetch_word
      fetch | (fetch << 8)
    end

    def handle_interrupts
      if @interrupt_line.nmi
        handle_nmi
      end
      if !@registers.interrupt? && @interrupt_line.irq
        handle_irq
      end
    end

    def handle_irq
      @interrupt_line.deassert_irq
      @registers.break = false
      push_word(@registers.program_counter)
      push(@registers.status)
      @registers.interrupt = true
      @registers.program_counter = read_word(INTERRUPTION_VECTOR_FOR_IRQ_OR_BRK)
    end

    def handle_nmi
      @interrupt_line.deassert_nmi
      @registers.break = false
      push_word(@registers.program_counter)
      push(@registers.status)
      @registers.interrupt = true
      @registers.program_counter = read_word(INTERRUPTION_VECTOR_FOR_NMI)
    end

    # @return [Integer]
    # @raise [Rnes::Errors::StackPointerOverflowError]
    def pop
      if @registers.stack_pointer < 0x1FF
        @registers.stack_pointer += 1
      else
        @registers.stack_pointer = 0x100
      end
      read(@registers.stack_pointer)
    end

    # @return [Integer]
    def pop_word
      pop | pop << 8
    end

    # @param [Integer] value
    # @raise [Rnes::Errors::StackPointerOverflowError]
    def push(value)
      write(@registers.stack_pointer, value)
      if @registers.stack_pointer > 0x100
        @registers.stack_pointer -= 1
      else
        @registers.stack_pointer = 0x1FF
      end
    end

    # @param [Integer] value
    def push_word(value)
      push(value >> 8)
      push(value & 0xFF)
    end

    # @param [Integer] address
    # @return [Integer]
    def read(address)
      @bus.read(address)
    end

    # @param [Integer] address
    # @return [Integer]
    def read_word(address)
      read(address) | read((address + 1) & 0xFFFF) << 8
    end

    # @param [Integer] byte Unsigned integer from 0x00 to 0xFF.
    def read_word_with_wrap_around(byte)
      low = read(byte)
      high = read((byte + 1) & 0xFF)
      low + (high << 8)
    end

    # @param [Integer] address
    # @param [Integer] value
    def write(address, value)
      @bus.write(address, value)
    end
  end
end


module Rnes
  class Logger
    # @param [Rnes::Cpu] cpu
    # @param [String] path
    # @param [Rnes::Ppu] ppu
    def initialize(cpu:, path:, ppu:)
      @cpu = cpu
      @path = path
      @ppu = ppu
    end

    def puts
      file.puts(line)
    end

    private

    # @return [File]
    def file
      @file ||= ::File.open(@path, 'w')
    end

    # @return [String]
    def line
      [
        segment_cpu_program_counter,
        '',
        segment_operation_code,
        segment_operand,
        '',
        segment_operation_full_name,
        segment_operand_humanized,
        '',
        segment_cpu_accumulator,
        segment_cpu_index_x,
        segment_cpu_index_y,
        segment_cpu_status,
        segment_cpu_stack_pointer,
        segment_cycle,
        segment_ppu_line,
      ].join(' ')
    end

    # @return [String]
    def segment_cpu_accumulator
      format('A:%02X', @cpu.registers.accumulator)
    end

    # @return [String]
    def segment_cpu_index_x
      format('X:%02X', @cpu.registers.index_x)
    end

    # @return [String]
    def segment_cpu_index_y
      format('Y:%02X', @cpu.registers.index_y)
    end

    # @return [String]
    def segment_cpu_program_counter
      format('%04X', @cpu.registers.program_counter)
    end

    # @return [String]
    def segment_cpu_stack_pointer
      format('SP:%02X', @cpu.registers.stack_pointer - 0x100)
    end

    # @return [String]
    def segment_cpu_status
      format('P:%02X', @cpu.registers.status)
    end

    # @return [String]
    def segment_cycle
      format('CYC:%3d', @ppu.cycle)
    end

    # @return [String]
    def segment_operand
      program_counter = @cpu.registers.program_counter
      operation = @cpu.read_operation
      case operation.addressing_mode
      when :absolute, :absolute_x, :absolute_y, :indirect_absolute
        format('%02X %02X', @cpu.bus.read(program_counter + 1), @cpu.bus.read(program_counter + 2))
      when :immediate, :relative, :zero_page, :zero_page_x, :zero_page_y, :pre_indexed_indirect, :post_indexed_indirect
        format('%02X   ', @cpu.bus.read(program_counter + 1))
      else
        ' ' * 5
      end
    end

    # @return [String]
    def segment_operand_humanized
      operation = @cpu.read_operation
      program_counter = @cpu.registers.program_counter
      string = begin
        case operation.addressing_mode
        when :absolute, :absolute_x, :absolute_y, :indirect_absolute, :pre_indexed_absolute, :post_indexed_absolute
          format('$%02X%02X', @cpu.bus.read(program_counter + 2), @cpu.bus.read(program_counter + 1))
        when :immediate, :relative, :zero_page, :zero_page_x, :zero_oage_y
          format('#$%02X', @cpu.bus.read(program_counter + 1))
        else
          ''
        end
      end
      format('%-19s', string)
    end

    # @return [String]
    def segment_operation_code
      operation = @cpu.read_operation
      operation_code = ::Rnes::Operation::RECORDS.find_index(operation.to_hash)
      format('%02X', operation_code)
    end

    # @return [String]
    def segment_operation_full_name
      operation = @cpu.read_operation
      format('%-10s', operation.full_name)
    end

    # @note SL means "Scan Line".
    # @return [String]
    def segment_ppu_line
      format('SL:%03d', @ppu.line)
    end
  end
end


module Rnes
  class PartsFactory
    CHARACTER_RAM_BYTESIZE = 2**12

    VIDEO_RAM_BYTESIZE = 2**13

    WORKING_RAM_BYTESIZE = 2**11

    # @return [Rnes::Ram]
    def character_ram
      @character_ram ||= ::Rnes::Ram.new(bytesize: CHARACTER_RAM_BYTESIZE)
    end

    # @return [Rnes::Cpu]
    def cpu
      @cpu ||= ::Rnes::Cpu.new(
        bus: cpu_bus,
        interrupt_line: interrupt_line,
      )
    end

    # @return [Rnes::CpuBus]
    def cpu_bus
      @cpu_bus ||= ::Rnes::CpuBus.new(
        dma_controller: dma_controller,
        keypad1: keypad1,
        keypad2: keypad2,
        ppu: ppu,
        ram: working_ram,
      )
    end

    # @return [Rnes::DmaController]
    def dma_controller
      @dma_controller ||= ::Rnes::DmaController.new(
        ppu: ppu,
        working_ram: working_ram,
      )
    end

    # @return [Rnes::InterruptLine]
    def interrupt_line
      @interrupt_line ||= ::Rnes::InterruptLine.new
    end

    # @return [Rnes::Keypad]
    def keypad1
      @keypad1 ||= ::Rnes::Keypad.new
    end

    # @return [Rnes::Keypad]
    def keypad2
      @keypad2 ||= ::Rnes::Keypad.new
    end

    # @return [Rnes::Ppu]
    def ppu
      @ppu ||= ::Rnes::Ppu.new(
        bus: ppu_bus,
        interrupt_line: interrupt_line,
        renderer: renderer,
      )
    end

    # @return [Rnes::PpuBus]
    def ppu_bus
      @ppu_bus ||= ::Rnes::PpuBus.new(
        character_ram: character_ram,
        video_ram: video_ram,
      )
    end

    # @return [Rnes::TerminalRenderer]
    def renderer
      @renderer ||= ::Rnes::TerminalRenderer.new
    end

    # @return [Rnes::Ram]
    def video_ram
      @video_ram ||= ::Rnes::Ram.new(bytesize: VIDEO_RAM_BYTESIZE)
    end

    # @return [Rnes::Ram]
    def working_ram
      @working_ram ||= ::Rnes::Ram.new(bytesize: WORKING_RAM_BYTESIZE)
    end
  end
end


module Rnes
  class Emulator
    # @param [String] log_file_path
    def initialize(log_file_path: nil)
      parts_factory = ::Rnes::PartsFactory.new
      @cpu = parts_factory.cpu
      @cpu_bus = parts_factory.cpu_bus
      @dma_controller = parts_factory.dma_controller
      @keypad1 = parts_factory.keypad1
      @keypad2 = parts_factory.keypad2
      @ppu = parts_factory.ppu
      @ppu_bus = parts_factory.ppu_bus
      if log_file_path
        @logger = ::Rnes::Logger.new(cpu: @cpu, path: log_file_path, ppu: @ppu)
      end
    end

    # @param [Array<Integer>] rom_bytes
    def load_rom(rom_bytes)
      rom_loader = ::Rnes::RomLoader.new(rom_bytes)
      copy(from: rom_loader.character_rom, to: @ppu_bus.character_ram)
      @cpu_bus.program_rom = rom_loader.program_rom
      @cpu.reset
    end

    def run
      allow_break_less_input
      $stdin.noecho do
        loop do
          if @logger
            @logger.puts
          end
          step
        end
      end
    ensure
      disallow_break_less_input
    end

    def step
      @dma_controller.transfer_if_requested
      (@cpu.step * 3).times do
        @ppu.step
      end
      @keypad1.check
      @keypad2.check
    end

    private

    def allow_break_less_input
      `stty -icanon min 1 time 0`
    end

    def disallow_break_less_input
      `stty icanon`
    end

    # @param [Rnes::Rom] from
    # @param [Rnes::Ram] to
    def copy(from:, to:)
      from.bytesize.times do |address|
        value = from.read(address)
        to.write(address, value)
      end
    end
  end
end

ROM_PATH = "/nes/rom.nes"
# --- interactive driver ------------------------------------------------------
# Protocol, one byte in / one frame out:
#   in   bit 0..7 = Right Left Down Up Start Select B A (rnes' own key order),
#        0xff = quit
#   out  256 * 240 * 3 bytes, RGB
module Rnes
  # The PPU calls renderer.render(image) exactly once per frame; that is the
  # only frame signal we need.
  class FrameSink
    attr_accessor :done
    def render(_image) = @done = true
  end

  class PartsFactory
    def renderer
      @renderer ||= ::Rnes::FrameSink.new
    end
  end

  class Emulator
    attr_reader :ppu, :keypad1, :renderer_sink
    def sink = @cpu_bus && nil || nil
  end

  class Keypad
    attr_accessor :buffer
    def check; end            # STDIN is the control channel here
  end

  class Image
    attr_reader :bytes
  end

  # rnes is Ruby-2-era: Operation.build does new(record) and relies on a Hash
  # auto-splatting into keywords, which Ruby 3 dropped.
  class Operation
    class << self
      def build(operation_code)
        record = ::Rnes::Operation::RECORDS[operation_code]
        raise ::Rnes::InvalidOperationCodeError, "Invalid operation code: #{operation_code}" unless record
        new(**record)
      end
    end
  end
end

emu     = Rnes::Emulator.new
factory = emu.instance_variable_get(:@ppu)
sink    = factory.instance_variable_get(:@renderer)
keypad  = emu.keypad1
ppu     = emu.ppu
emu.load_rom(File.binread(ROM_PATH).bytes)

# NES has no palette to hand over (rnes writes RGB directly); keep the wire
# format the same as the other pages with an empty palette block.
$stdout.write("PAL0")
$stdout.write(([0] * 768).pack("C*"))

loop do
  b = STDIN.read(1)
  break if b.nil?
  v = b.unpack1("C")
  break if v == 0xff
  keypad.buffer = v

  sink.done = false
  until sink.done
    emu.step
  end
  $stdout.write(ppu.image.bytes.flatten.pack("C*"))
  $stdout.flush
end
