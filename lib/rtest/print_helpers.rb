# lib/print_helpers.rb

module Rtest
  module PrintHelpers
    def print_wrapped_test_name(color, display_number, test_name, first_line_prefix = '')
      name_lines = truncate_long_line(test_name)
      if name_lines.size == 1
        puts "\n#{first_line_prefix}#{color}#{display_number}: #{name_lines.first}#{COLOR_RESET}\n"
      elsif name_lines.size == 0
        puts "\n#{first_line_prefix}#{color}NON-TEST ERROR#{COLOR_RESET}\n"
      else
        number_spaces = ' ' * (display_number.to_s.length + 1 + first_line_prefix.to_s.length)
        puts "\n#{first_line_prefix}#{color}#{display_number}: #{name_lines.first}#{COLOR_RESET}\n"
        name_lines[1..-1].each do |line|
          puts "#{color}#{number_spaces}  #{line.lstrip}#{COLOR_RESET}"
        end
      end
    end

    def truncate_long_line(line, max = SCREEN_WIDTH)
      new_lines = []
      return new_lines if line.nil?

      split_on = next_split_char(line, max)
      return [line] if split_on.nil?

      new_lines << line[0..split_on] + COLOR_RESET
      remainder = line[split_on..-1]
      # if remainder.size > max
      if unescape(remainder).size > max && ! next_split_char(remainder, max).nil?
        new_lines += truncate_long_line(remainder, max)
      elsif !unescape(remainder).strip.empty?
        new_lines << remainder
      end
      new_lines
    end

    def truncate_long_lines(lines, _max = SCREEN_WIDTH)
      new_lines = []
      lines.each do |line|
        if line.length <= SCREEN_WIDTH
          new_lines << line
        else
          new_lines += truncate_long_line(line)
        end
      end
      new_lines
    end

    private
    def next_split_char(line, max)
      spaces = (0...line.length).find_all { |i| line[i, 1].match(/\s/) }
      splits = spaces.select { |x| x <= max }
      # split on the first space < 90% of the length
      splits.select { |x| x < (max * 0.9) }.last
    end
  end
end
