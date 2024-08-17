require 'curses'


file = ARGV.shift || fail("You must supply a file to view")
File.exist?(file) || fail("You must supply a valid file path. #{file} doesn't exist.")

$log = File.open("/tmp/z.log", "w+")
$log.sync = true

Dimensions = Struct.new(:x, :y, :width, :height, keyword_init: true)

class ViewPort
  attr_reader :dimensions, :lines, :window, :viewable_dimensions

  def initialize(window, lines)
    @lines = lines
    @dimensions = Dimensions.new(x: 0, y: 0, width: window.maxx - 1, height: window.maxy - 1)
    @viewable_dimensions = @dimensions.dup
    @window = window
  end

  def contents
    lines[viewable_dimensions.y...viewable_dimensions.height].map do |line|
      line[viewable_dimensions.x...viewable_dimensions.width] + "\n"
    end.join
  end

  def draw
    window.setpos 0, 0
    window.addstr contents
    window.refresh
  end

  def resize
    @dimensions = Dimensions.new(x: 0, y: 0, width: window.maxx - 1, height: window.maxy - 1),
    new_viewable_dimensions = Dimensions.new(
      x: viewable_dimensions.x,
      y: viewable_dimensions.y,
      width: window.maxx - 1,
      height: window.maxy - 1
    )
    @viewable_dimensions = new_viewable_dimensions
    draw
  end

  def scroll_y(num)
    if num.positive?
      if viewable_dimensions.height < lines.length
        new_viewable_dimensions = Dimensions.new(
          x: viewable_dimensions.x,
          y: viewable_dimensions.y + 1,
          width: viewable_dimensions.width,
          height: viewable_dimensions.height + 1
        )
        @viewable_dimensions = new_viewable_dimensions
        window.setpos dimensions.height, 0
        window.addstr contents.lines.last
      end
    elsif num.negative?
      if viewable_dimensions.y > 0
        new_viewable_dimensions = Dimensions.new(
          x: viewable_dimensions.x,
          y: viewable_dimensions.y - 1,
          width: viewable_dimensions.width,
          height: viewable_dimensions.height - 1
        )
        @viewable_dimensions = new_viewable_dimensions
        window.scrl -1
        window.setpos 0, 0
        window.addstr contents.lines.first
      end
    end
  end
end

begin
  Curses.cbreak
  Curses.curs_set 0
  Curses.noecho

  window = Curses.init_screen
  window.keypad = true
  window.scrollok true

  view_port = ViewPort.new(
    window,
    File.read(file).lines.map(&:chomp)
  )

  Signal.trap('SIGWINCH') do
    $log.puts "resizing"
    view_port.resize
  end

  view_port.draw

  loop do
    while ch=window.getch
      case ch
        when "q"
          exit 0
        when Curses::KEY_DOWN
          view_port.scroll_y(1)
        when Curses::KEY_UP
          view_port.scroll_y(-1)
      end

      window.refresh
    end
  end
ensure
  Curses.close_screen
  $log.close
end
