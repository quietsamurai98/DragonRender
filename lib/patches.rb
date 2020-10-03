module GTK
  class Console
    def mouse_wheel_scroll args
      @inertia ||= 0

      if args.inputs.mouse.wheel && args.inputs.mouse.wheel.y > 0
        @inertia = -1
      elsif args.inputs.mouse.wheel && args.inputs.mouse.wheel.y < 0
        @inertia = 1
      end

      if args.inputs.mouse.click
        @inertia = 0
      end

      return if @inertia == 0

      if @inertia != 0
        @inertia = (@inertia * 0.7)
        if @inertia > 0
          @log_offset -= 1
        elsif @inertia < 0
          @log_offset += 1
        end
      end

      if @inertia.abs < 0.01
        @inertia = 0
      end

      if @log_offset > @log.size
        @log_offset = @log.size
      elsif @log_offset < 0
        @log_offset = 0
      end
    end

    def process_inputs(args)
      if console_toggle_key_down? args
        args.inputs.text.clear
        toggle
      end

      return unless visible?

      args.inputs.text.each { |str| prompt << str }
      args.inputs.text.clear
      mouse_wheel_scroll args

      @log_offset = 0 if @log_offset < 0

      if args.inputs.keyboard.key_down.enter
        eval_the_set_command
      elsif args.inputs.keyboard.key_down.v
        if args.inputs.keyboard.key_down.control || args.inputs.keyboard.key_down.meta
          prompt << $gtk.ffi_misc.getclipboard
        end
      elsif args.inputs.keyboard.key_down.up
        if @command_history_index == -1
          @nonhistory_input = current_input_str
        end
        if @command_history_index < (@command_history.length - 1)
          @command_history_index += 1
          self.current_input_str = @command_history[@command_history_index].dup
        end
      elsif args.inputs.keyboard.key_down.down
        if @command_history_index == 0
          @command_history_index = -1
          self.current_input_str = @nonhistory_input
          @nonhistory_input      = ''
        elsif @command_history_index > 0
          @command_history_index -= 1
          self.current_input_str = @command_history[@command_history_index].dup
        end
      elsif args.inputs.keyboard.key_down.left
        prompt.move_cursor_left
      elsif args.inputs.keyboard.key_down.right
        prompt.move_cursor_right
      elsif inputs_scroll_up_full? args
        scroll_up_full
      elsif inputs_scroll_down_full? args
        scroll_down_full
      elsif inputs_scroll_up_half? args
        scroll_up_half
      elsif inputs_scroll_down_half? args
        scroll_down_half
      elsif inputs_clear_command? args
        prompt.clear
        @command_history_index = -1
        @nonhistory_input      = ''
      elsif args.inputs.keyboard.key_down.backspace || args.inputs.keyboard.key_down.delete
        prompt.backspace
      elsif args.inputs.keyboard.key_down.tab
        prompt.autocomplete
      end

      args.inputs.keyboard.key_down.clear
      args.inputs.keyboard.key_up.clear
      args.inputs.keyboard.key_held.clear
    end
    class Prompt
      def initialize(font_style:, text_color:, console_text_width:)
        @prompt = '-> '
        @current_input_str = ''
        @font_style = font_style
        @text_color = text_color
        @cursor_color = Color.new [187, 21, 6]
        @console_text_width = console_text_width

        @cursor_position = 0

        @last_autocomplete_prefix = nil
        @next_candidate_index = 0
      end
      def current_input_str=(str)
        @current_input_str = str
        @cursor_position = str.length
      end

      def <<(str)
        @current_input_str = @current_input_str[0...@cursor_position] + str + @current_input_str[@cursor_position..-1]
        @cursor_position += str.length
        @current_input_changed_at = Kernel.global_tick_count
        reset_autocomplete
      end

      def backspace
        return if current_input_str.length.zero? || @cursor_position.zero?

        @current_input_str = @current_input_str[0...(@cursor_position - 1)] + @current_input_str[@cursor_position..-1]
        @cursor_position -= 1
        reset_autocomplete
      end
      def clear
        @current_input_str = ''
        @cursor_position = 0
        reset_autocomplete
      end
      def render(args, x:, y:)
        args.outputs.reserved << font_style.label(x: x, y: y, text: "#{@prompt}#{current_input_str}", color: @text_color)
        args.outputs.reserved << font_style.label(x: x - 4, y: y + 3, text: (" " * (@prompt.length + @cursor_position)) + "|", color: @cursor_color)
      end
      def move_cursor_left
        @cursor_position -= 1 if @cursor_position > 0
      end

      def move_cursor_right
        @cursor_position += 1 if @cursor_position < current_input_str.length
      end

    end
  end
  class Runtime
    module FramerateDiagnostics
      def framerate_diagnostics_primitives
        lines = []
        lines.push("solids:     #{@args.outputs.solids.length}, #{@args.outputs.static_solids.length}") unless @args.outputs.solids.length+@args.outputs.static_solids.length == 0
        #lines.push("sprites:    #{@args.outputs.sprites.length}, #{@args.outputs.static_sprites.length}") unless @args.outputs.sprites.length+@args.outputs.static_sprites.length == 0
        lines.push("primitives: #{@args.outputs.primitives.length}, #{@args.outputs.static_primitives.length}") unless @args.outputs.primitives.length+@args.outputs.static_primitives.length == 0
        #lines.push("labels:     #{@args.outputs.labels.length}, #{@args.outputs.static_labels.length}") unless @args.outputs.labels.length+@args.outputs.static_labels.length == 0
        lines.push("lines:      #{@args.outputs.lines.length}, #{@args.outputs.static_lines.length}") unless @args.outputs.lines.length+@args.outputs.static_lines.length == 0
        #lines.push("borders:    #{@args.outputs.borders.length}, #{@args.outputs.static_borders.length}") unless @args.outputs.borders.length+@args.outputs.static_borders.length == 0
        #lines.push("debug:      #{@args.outputs.debug.length}, #{@args.outputs.static_debug.length}") unless @args.outputs.debug.length+@args.outputs.static_debug.length == 0
        #lines.push("reserved:   #{@args.outputs.reserved.length}, #{@args.outputs.static_reserved.length}") unless @args.outputs.reserved.length+@args.outputs.static_reserved.length == 0
        out = [
            { x: 0, y: 93.from_top, w: 500, h: 93, a: 128 }.solid,
            {
                x: 5,
                y: 5.from_top,
                text: "More Info via DragonRuby Console: $gtk.framerate_diagnostics",
                r: 255,
                g: 0,
                b: 0,
                size_enum: -2
            }.label,
            {
                x: 5,
                y: 20.from_top,
                text: "FPS: %.2f" % args.gtk.current_framerate,
                r: 255,
                g: 0,
                b: 0,
                size_enum: -2
            }.label,
            {
                x: 5,
                y: 35.from_top,
                text: "Draw Calls: #{$perf_counter_outputs_push_count}",
                r: 255,
                g: 0,
                b: 0,
                size_enum: -2
            }.label,
            {
                x: 5,
                y: 50.from_top,
                text: "Array Primitives: #{$perf_counter_primitive_is_array}",
                r: 255,
                g: 0,
                b: 0,
                size_enum: -2
            }.label,
            {
                x: 5,
                y: 65.from_top,
                text: "Mouse: #{@args.inputs.mouse.point}",
                r: 255,
                g: 0,
                b: 0,
                size_enum: -2
            }.label,
        ]
        lines.each do |line|
          out.push({
              x: 5,
              y: out[-1].y - 15,
              text: line,
              r: 255,
              g: 0,
              b: 0,
              size_enum: -2
          }.label)
          out[0].h += 15
          out[0].y -= 15
        end
        out
      end
    end
  end
end

class Array
  include XYPairMath
  def z
    w
  end
end
class Hash
  def z
    self[:z]
  end
end