require 'curses'
#require "debug/open"

file = ARGV.shift || fail("You must supply a file to view")
File.exist?(file) || fail("You must supply a valid file path. #{file} doesn't exist.")

$log = File.open("/tmp/z.log", "w+")
$log.sync = true

Dimensions = Struct.new(:x, :y, :width, :height, keyword_init: true)

class ViewPort
  attr_reader :dimensions, :lines, :window, :viewable_dimensions

  def initialize(window, lines)
    @lines = lines
    @lines.push("\n") if lines.last.end_with?("\n")
    @dimensions = Dimensions.new(x: 0, y: 0, width: window.maxx, height: window.maxy)
    @viewable_dimensions = @dimensions.dup
    @window = window
  end

  def contents
    $log.puts "CONTENTS WIDTH: #{(viewable_dimensions.x...viewable_dimensions.width).inspect}"
    $log.puts "CONTENTS HEIGHT: #{(viewable_dimensions.y...viewable_dimensions.height).inspect}"
    lines[viewable_dimensions.y...viewable_dimensions.height].map do |line|
      line[viewable_dimensions.x...viewable_dimensions.width].to_s.sub(%r{\n+$}, "")
    end
  end

  def draw
    window.clear
    contents.each.with_index do |line, index|
      window.setpos index, 0
      $log.puts "addstr: #{line.inspect}\tsetpos: #{index}"
      window.addstr line
    end
    $log.puts "viewable_dimensions: #{viewable_dimensions.inspect}"
    $log.puts "contents: #{contents.inspect}"
    $log.puts

    window.refresh
  end

  def resize
    old_dimensions = dimensions
    new_dimensions = Dimensions.new(x: 0, y: 0, width: window.maxx, height: window.maxy)

    $log.puts "old dimensions: #{@dimensions.inspect}"
    @dimensions = Dimensions.new(x: 0, y: 0, width: window.maxx, height: window.maxy)
    $log.puts "new dimensions: #{@dimensions.inspect}"

    new_viewable_dimensions = Dimensions.new(
      x: viewable_dimensions.x,
      y: viewable_dimensions.y,
      width: window.maxx,
      height: viewable_dimensions.y + window.maxy
    )
    $log.puts "old viewables dimensions: #{@viewable_dimensions.inspect}"
    @viewable_dimensions = new_viewable_dimensions
    $log.puts "new viewables dimensions: #{@viewable_dimensions.inspect}"
    $log.puts
    draw
  end

  def scroll_up
    scroll_y(-1)
  end

  def scroll_down
    scroll_y(1)
  end

  def scroll_left
    scroll_x(-11)
  end

  def scroll_right
    scroll_x(1)
  end

  def max_line_width
    lines.map(&:length).max
  end

  def scroll_x(num)
    if num.positive?
      if viewable_dimensions.width < max_line_width
        new_viewable_dimensions = Dimensions.new(
          x: viewable_dimensions.x + 1,
          y: viewable_dimensions.y,
          width: viewable_dimensions.width + 1,
          height: viewable_dimensions.height
        )
        @viewable_dimensions = new_viewable_dimensions

        $log.puts "viewable_dimensions: #{viewable_dimensions.inspect}"
        $log.puts "  contents: #{contents.inspect}"

        draw
      end
    elsif num.negative?
      if viewable_dimensions.x > 0
        new_viewable_dimensions = Dimensions.new(
          x: viewable_dimensions.x - 1,
          y: viewable_dimensions.y,
          width: viewable_dimensions.width - 1,
          height: viewable_dimensions.height
        )
        @viewable_dimensions = new_viewable_dimensions

        $log.puts "viewable_dimensions: #{viewable_dimensions.inspect}"
        $log.puts "  contents: #{contents.inspect}"

        window.addstr contents.first
        draw
      end
    end
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
        window.scrl 1
        window.setpos dimensions.height - 1, 0

    $log.puts "viewable_dimensions: #{viewable_dimensions.inspect}"
    $log.puts "  contents: #{contents.inspect}"
#    $log.puts "  lines: #{lines.inspect}"
    $log.puts

        window.addstr contents.last
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

    $log.puts "viewable_dimensions: #{viewable_dimensions.inspect}"
    $log.puts "  contents: #{contents.inspect}"
#    $log.puts "  lines: #{lines.inspect}"
    $log.puts

        window.addstr contents.first
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
    File.read(file).gsub(" ", ".").lines
  )

  view_port.draw

  loop do
    while ch=window.getch
      case ch
        when "q"
          exit 0
        when Curses::KEY_RESIZE
          $log.puts "WINDOW RESIZE: x=#{window.maxx}\ty=#{window.maxy}"
          view_port.resize
        when Curses::KEY_DOWN
          view_port.scroll_down
        when Curses::KEY_UP
          view_port.scroll_up
        when Curses::KEY_LEFT
          view_port.scroll_left
        when Curses::KEY_RIGHT
          view_port.scroll_right
      end

      window.refresh
    end
  end
ensure
  Curses.close_screen
  $log.close
end
