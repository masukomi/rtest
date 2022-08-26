# frozen_string_literal: true

require_relative 'common'
require_relative '../constants'
require_relative 'print_helpers'

module Rtest
  class FailurePrinter
    include PrintHelpers
    include Rtest::Common
    def self.print(failure, potential_display_number = -1)
      f = FailurePrinter.new(failure, potential_display_number)
      f.begin
    end

    def self.display_failures(failures)
      if failures.size.positive?
        failures.each_with_index do |failure, idx|
          FailurePrinter.print(failure, idx)
        end
      else
        puts NO_FAILURES_TEXT
      end
    end

    attr_accessor :failure, :potential_display_number

    def initialize(failure, potential_display_number = -1)
      self.failure = failure
      self.potential_display_number = potential_display_number
    end

    def begin
      print_description(failure, potential_display_number + 1)

      puts printable_failure_notes(failure) if failure.has_notes?
      puts ''

      puts printable_file_and_line_num(failure)

      puts "\t#{EXPECTED_LINE_COLOR}expected: #{failure.expected}#{COLOR_RESET}" if failure.expected
      puts "\t#{GOT_LINE_COLOR}got     : #{failure.got}#{COLOR_RESET}" if failure.got

      puts printable_backtrace(failure.backtrace)
    end

    private

    def print_description(failure, potential_display_number)
      display_number = if failure.display_number.nil?
                         potential_display_number
                       else
                         failure.display_number
                       end

      print_wrapped_test_name(ERROR_LINE_COLOR, display_number, failure.test_name)

      if failure.description.size > 1
        # well crap. We're dealing with something like this
        # [
        #   "expect do",
        #   "object.upload_stream(tempfile: true) do |write_stream|",
        #   "write_stream << seventeen_mb",
        #   "end",
        #   "end.to raise_error(",
        #   "S3::MultipartUploadError,",
        #   "'failed to abort multipart upload: network-error'",
        #   ")",
        # ]

        failure.description.each do |line|
          puts "\t#{DETAIL_LINE_COLOR}#{line}#{COLOR_RESET}"
        end
      end
    end

    def printable_failure_notes(failure)
      displayable_list = VERBOSE ? failure.failure_notes : failure.failure_notes[0..9]
      displayable_list = displayable_list.map { |note| note.split(/\\n|\n/) }.flatten
      displayable_list = truncate_long_lines(displayable_list)
      path_lines_truncator("\t#{FAILURE_NOTE_LINE_COLOR}",
                           displayable_list.map { |x| "\t#{COLOR_RESET}▷ #{x}" },
                           COLOR_RESET,
                           { force: true })
      # "\n\t#{FAILURE_NOTE_LINE_COLOR}" + displayable_list.join("\n\t") + COLOR_RESET
    end

    def printable_file_and_line_num(failure)
      lines = []

      if failure.spec_file_path
        # if so, we're going to display the spec error & where it blew up in the file
        lines << path_line_truncator(
          "\tFAILED SPEC : #{ERROR_HERE_LINE_COLOR}",
          failure.spec_file_path,
          "#{COLOR_RESET}:#{LINE_NUMBER_COLOR}#{failure.spec_line_number}#{COLOR_RESET}"
        )

      end
      if failure.error_file_path
        lines << path_line_truncator("\tERROR HERE  : #{ERROR_HERE_LINE_COLOR}",
                                     failure.error_file_path,
                                     "#{COLOR_RESET}:#{LINE_NUMBER_COLOR}#{failure.error_line_number}#{COLOR_RESET}")
        lines << "\t             in -> #{failure.error_method}" if failure.error_method

      elsif failure.error_method
        lines << "\tERROR METHOD: #{ERROR_HERE_LINE_COLOR}#{failure.error_method}#{COLOR_RESET}"
      end
      lines.join("\n")
    end

    def printable_backtrace(backtrace)
      displayable_list = VERBOSE ? backtrace : backtrace[0..9]

      if displayable_list.size.positive?
        "\n" + path_lines_truncator("\t#{BACKTRACE_COLOR}",
                                    displayable_list,
                                    COLOR_RESET,
                                    { force: true })
      else
        "\n\t#{BACKTRACE_COLOR}Backtrace Unavailable#{COLOR_RESET}"
      end
      # "\t#{BACKTRACE_COLOR}" + displayable_list.join("\n\t") + COLOR_RESET
    end

    def path_lines_truncator(preface, paths, suffix, line_options = {})
      paths.map do |maybe_path|
        if line_is_path?(unescape(maybe_path))
          path_line_truncator(preface, maybe_path, suffix, line_options)
        else
          maybe_path
        end
      end.join("\n")
    end

    # a path line is a line that ends in a file path
    # it may or may not, have a preface.
    # to force truncation even when not in shortened_paths mode
    # set line_options[:force] = true
    def path_line_truncator(preface, path, suffix, line_options = {})
      # TODO: calculate how long a tab stop is
      # for now i'm assuming the default of 8 characters
      line_options[:soft_max] = SCREEN_WIDTH unless line_options[:soft_max]

      untruncated_line = preface + path + suffix
      if !OPTIONS[:shortened_paths] && !line_options[:force]
        untruncated_line
      else
        tab_length = 8
        preface ||= ''
        unescaped_preface = unescape(preface)
        unescaped_suffix = unescape(suffix)
        non_file_length =  unescaped_preface.length \
                           + (unescaped_preface.gsub(/[^\t]/, '').length \
                              * (tab_length - 1)) \
                           + unescaped_suffix.length

        basename = File.basename(path)
        elipsis_basename = "…#{File::SEPARATOR}#{basename}"

        if basename.length >= line_options[:soft_max]
          elipsis_basename
        else
          available_chars = line_options[:soft_max] \
                            - elipsis_basename.length \
                            - non_file_length
          path_chunks = path.split(File::SEPARATOR)
          returnable = []

          # efficient? no, not really, but easy to think about? yes
          # and yeah, there's got to be a better way to do this.
          # TODO: refactor this to be less... kludgey
          (0..path_chunks.length).each do |index|
            if index != path_chunks.length
              chunk = path_chunks[index]
              returnable << chunk
              if returnable.join(File::SEPARATOR).length > available_chars
                return preface +
                       (returnable[0..-2] + [elipsis_basename]).join(File::SEPARATOR) +
                       suffix
              end
            else
              return untruncated_line
            end
          end
        end
      end
    end

    # only used for truncation decision
    # it's unlikely any single file name in the current dir
    # will be long enough to need truncation ;)
    def line_is_path?(line)
      line.split(File::SEPARATOR).size > 1 \
        && %r{^\s*\.?/}.match(line)
    end
  end
end
