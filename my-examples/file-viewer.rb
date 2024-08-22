require 'curses'
require 'shellwords'
require 'delegate'
require "pry-byebug"
#require "debug/open"

file = ARGV.shift || fail("You must supply a file to view")
File.exist?(file) || fail("You must supply a valid file path. #{file} doesn't exist.")

$log = File.open("/tmp/z.log", "w+")
$log.sync = true

Dimensions = Struct.new(:x, :y, :width, :height, keyword_init: true)

class ViewPort
  attr_reader :dimensions, :texts, :window, :viewable_dimensions

  def initialize(window, texts)
    @texts = texts
    @dimensions = Dimensions.new(x: 0, y: 0, width: window.maxx, height: window.maxy)
    @viewable_dimensions = @dimensions.dup
    @window = window
  end

  def lines
    texts.lines
  end

  def contents
    $log.puts "CONTENTS WIDTH: #{(viewable_dimensions.x...viewable_dimensions.width).inspect}"
    $log.puts "CONTENTS HEIGHT: #{(viewable_dimensions.y...viewable_dimensions.height).inspect}"
    lines[viewable_dimensions.y...viewable_dimensions.height].map do |line|
      line[viewable_dimensions.x...viewable_dimensions.width].to_s.chomp
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

class Text < SimpleDelegator
  attr_reader :attr, :text

  def initialize(attr: nil, text:)
    @attr = attr
    @text = text
    super(@text)
  end

  def [](value)
    text = super
    Text.new(attr: attr.dup, text: text)
  end
end

class Line
  attr_reader :text_nodes

  def initialize(text_nodes = [])
    @text_nodes = text_nodes
  end

  def <<(text_node)
    @text_nodes << text_node
  end

  def length
    to_s.length
  end

  def [](value)
    $log.puts "-"*100
    $log.puts "value: #{value.inspect}"

    case value
    when Range
      position = 0
      min, max = value.min, value.max
      text_nodes.each_with_object(Line.new) do |text, line|
        next if text.length == 0
#sbinding.pry if value.min > 0
#          binding.pry if min == 3
        if position >= min && position + text.length <= max
          $log.puts "B position:#{position} min:#{min} max:#{max} length:#{length} range:#{(position..text.length)} text:#{text[0..text.length].inspect} "
          line << text[0..text.length]
          position += text.length
 #       $log.puts "B position: #{position}"
        elsif position < min && position + text.length > min && position + text.length < max
          $log.puts "C position:#{position} min:#{min} max:#{max} length:#{length} range:#{(min-position..text.length)} text:#{text[min-position..text.length].inspect} "

          line << text[min-position..text.length]
          $log.puts "postion was: #{position} is: #{position + text.length - min-position}"
          position += text.length
        elsif position < min && position + text.length > min && position + text.length > max
          $log.puts "C2 position:#{position} min:#{min} max:#{max} length:#{length} range:#{(min-position..text.length-max)} text:#{text[min-position..text.length-max].inspect} "

#binding.pry if min == 11
          line << text[min-position..max-position]
          $log.puts "postion was: #{position} is: #{position + max}"
          position += text.length
        elsif position >= min && position + text.length > max
          end_range = max - position
          next if end_range == 0
          $log.puts "D position:#{position} min:#{min} max:#{max} length:#{length} range:#{(0..end_range)} text:#{text[0..end_range].inspect} "
#          binding.pry
          line << text[0..end_range]
          position += end_range
  #       $log.puts "C position: #{position}"
        elsif position >= min
          $log.puts "E position:#{position} min:#{min} max:#{max} length:#{length} range:#{(0..text.length)} text:#{text[0..text.length].inspect} "
          # $log.puts "position:#{position} min:#{min} max:#{max} length:#{length} text:#{text[min..max].inspect}"
    #       line << text[0..text.length]
          line << text[0..text.length]
          position += text.length
#          fail "Not implemented 2"
        else
          $log.puts "ELSE min:#{min} max:#{max} postion was: #{position} is: #{position + text.length}"
          position += [max,text.length].min
        end
#        $log.puts "E position: #{position}"
      end
    else
      fail "Not implemented 1"
    end
  end

  def to_s
    text_nodes.map(&:to_s).join
  end
end

class Texts
  attr_reader :text_nodes

  def initialize(text_nodes)
    @text_nodes = text_nodes
  end

  def lines
    lines = []
    line = Line.new
    text_nodes.each do |text_node|
      if text_node.include?("\n")
        text_node.scan(/^[^\n]*\n/).each do |raw_text_with_newline|
          line << Text.new(attr: text_node.attr, text: raw_text_with_newline)
          lines << line
          line = Line.new
        end
      else
        line << text_node
      end
    end
    lines
  end

  def inspect
    lines.join
  end
end

begin
  Curses.cbreak
  Curses.curs_set 0
  Curses.noecho

  window = Curses.init_screen
  window.keypad = true
  window.scrollok true

  output = %x{pygmentize #{file.shellescape}}

  raw_texts = output.scan(%r{(\e\[[0-9;]*m)|([^\e]+)}).map do |ansii, text|
    Text.new(attr: ansii, text: text.to_s)
  end

  texts = Texts.new(raw_texts)

  view_port = ViewPort.new(
    window,
    texts
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
