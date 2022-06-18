# RSpec::Core::Example notes
#  methods relevant to this work
#  - description
#    - "test_convert_error"
#  - example_group
#  - execution_result -> ExecutionResult object
#    #<RSpec::Core::Example::ExecutionResult:0x0000000106586310
#      @started_at=2022-06-17 11:27:17.447464 -0400,
#      @status=:failed,
#      @finished_at=2022-06-17 11:27:17.453267 -0400,
#      @run_time=0.005803,
#      @exception=#<RSpec::Expectations::ExpectationNotMetError:
#        expected: == "INTENTIONAL FAILURE" got:    "ick">>
#  - file_path
#  - full_description
#    - "Multipart::Post::CompositeReadIO test_convert_error"
#  - id
#  - inspect (just for debugging)
#  - inspect_output (description + guaranteed location included)
#  - location - exact source location of this example:
#               ex ./path/to/spec.rb:17
#  - location_rerun_argument
#    - returns the location-based argument that can be passed to the rspec command to rerun
#      this example
#    - ?? typically the same as the location
#  - pending?
#  - skipped?

require 'json'


class Failure
  # The regex to match ANSI codes
  # from https://github.com/piotrmurach/strings-ansi
  ANSI_MATCHER = %r{
    (?>\033(
      \[[\[?>!]?\d*(;\d+)*[ ]?[a-zA-Z~@$^\]_\{\\] # graphics
      |
      \#?\d # cursor modes
      |
      [)(%+\-*/. ](\d|[a-zA-Z@=%]|) # character sets
      |
      O[p-xA-Z] # special keys
      |
      [a-zA-Z=><~\}|] # cursor movement
      |
      \]8;[^;]*;.*?(\033\\|\07) # hyperlink
    ))
  }x.freeze

  attr_accessor :backtrace,
                :description,
                :error_file_path,
                :error_line_number,
                :error_method,
                :expected,
                :failure_notes,
                :got,
                :spec_line_number,
                :rspec_arg,
                :run_time,
                :spec_file_path,
                :spec_location,
                :test_name

  # example: RSpec::Core::Example
  # failure: FailedExampleNotification
  def initialize(notification)
# require 'byebug'; byebug
    self.failure_notes=[]
    self.description = []

    example = notification.example

    extract_attrs_from_example(example)
    extract_attrs_from_notification(notification)
  end

  # removes gems, rspec, and bundle lines from your backtrace
  # This, of course, presumes you're not actually editing one
  # of those.
  def filtered_backtrace
    elliptified_lines = backtrace.map{ |line| filterable_line?(line) ? "…" : line }
    returnable_lines = []
    elliptified_lines.each_with_index{ |line, idx|
      if line != "…" && idx != 0
        returnable_lines << line
      elsif idx > 0 \
            && ! returnable_lines.empty? \
            && returnable_lines.last != "…"
        returnable_lines << line
      end

    }
    return returnable_lines if returnable_lines.last != "…"
    returnable_lines[0..-2]
  end
  def filterable_line?(line)
    line.include?("/lib/ruby/") \
      || line.include?("/bin/rspec") \
      || line.include?("/bin/bundle") \
      || line.include?("/spec_helper.rb")
  end

  def to_json
    hash = {}
    self.instance_variables.map{ |x| x.to_s.sub("@", "").to_sym }.each do | method |
      hash[method] = self.send(method)
    end
    hash[:backtrace] = filtered_backtrace

    JSON.pretty_generate(hash)
  end

  def inspect
    self.to_json
  end

  private

  def unescape(text)
    text.gsub(ANSI_MATCHER, '')
  end

  def extract_attrs_from_example(example)
    self.rspec_arg = example.location_rerun_argument
    self.spec_file_path = example.file_path
    self.run_time = example.execution_result.run_time
    self.spec_line_number = extract_line_number(example.location)
    self.spec_location = example.location
  end

  def extract_attrs_from_notification(notification)
    self.test_name = notification.description
    self.backtrace = notification.formatted_backtrace || []
    extract_message_elements(notification)

    extract_failure_location(filtered_backtrace)
  end


  def extract_message_elements(notification)
    lines = notification
              .colorized_message_lines # .map{ |line| unescape(line.sub(/^\s+/, '')) }
              .reject{ |line| line.empty? }
    # sholud be [failure/error, expected, got, <optional comparison note>]
    # but i don't want to assume


    complex_extraction = unescape(lines.first) == "Failure/Error:" \
                         || lines.any?{ |line| !! /^expected .*?, got /.match(unescape(line)) }
    if complex_extraction
      # require 'byebug'; byebug
      complex_message_extraction(lines)
    else
      simple_message_extraction(lines)
    end
  end

  def simple_message_extraction(lines)
    # require 'byebug'; byebug
    lines.each do | line|
      unescaped_line = unescape(line)
      prefix, content = message_line_components(unescaped_line)
      message_line_assignment_by_prefix(prefix, content, unescaped_line)
    end
  end
  def message_line_assignment_by_prefix(prefix, content, line)
    if prefix == "Failure/Error"
      self.description  << content
      return true
    elsif prefix == "expected"
      self.expected = content
      return true
    elsif prefix == "got"
      self.got = content
      return true
    elsif ! unescape(line).strip.empty?
          # require 'byebug'; byebug
      # it's a non-blank line with content that isn't one of the above...
      #require 'byebug'; byebug
      self.failure_notes << line
      return true
    end
    false
  end
  def message_line_components(line)
    # presumes an unescaped line
    # prefix, content
    [line.sub(/^\s*(\S+.*):.*/, '\1'), line.sub(/^.*?:\s*/, '')]
  end
  def complex_message_extraction(lines)
    # assumptions
    # first line:
    #   "Failure/Erorr:"
    # unknown number of lines then
    #   "expected <something>, got <something else>"
    # MAYBE ending in
    #   " with backtrace:"
    # followed by lines of backtrace starting with
    #   "# "
    #  ---- ACTUAL EXAMPLE ---
    #  [
    #   "Failure/Error:",
    #   "expect do",
    #   "object.upload_stream(tempfile: true) do |write_stream|",
    #   "write_stream << seventeen_mb",
    #   "end",
    #   "end.to raise_error(",
    #   "S3::MultipartUploadError,",
    #   "'failed to abort multipart upload: network-error'",
    #   ")",
    #   "expected Aws::S3::MultipartUploadError with \"failed to abort multipart upload: network-error\", got #<Aws::S3::MultipartUploadError: failed to abort multipart upload: network-error💥> with backtrace:",
    #   "# ./lib/aws-sdk-s3/multipart_stream_uploader.rb:99:in `rescue in abort_upload'",
    #   "# ./lib/aws-sdk-s3/multipart_stream_uploader.rb:87:in `abort_upload'",
    #   "# ./lib/aws-sdk-s3/multipart_stream_uploader.rb:83:in `upload_parts'",
    #   "# ./lib/aws-sdk-s3/multipart_stream_uploader.rb:45:in `upload'",
    #   "# ./lib/aws-sdk-s3/customizations/object.rb:371:in `upload_stream'",
    #   "# ./spec/object/upload_stream_spec.rb:449:in `block (5 levels) in <module:S3>'",
    #   "# ./spec/object/upload_stream_spec.rb:448:in `block (4 levels) in <module:S3>'"
    # ]
    open('/Users/masukomi/workspace/reference/ruby/aws-sdk-ruby/build_tools/debugger.txt', 'a') { |f| f.puts "complex error message:\n#{JSON.pretty_generate(lines)}" }

          # require 'byebug'; byebug
    in_backtrace = false
    # 1st line is useless
    lines[1..-1].each do | line |
      unescaped_line = unescape(line)
      # can't figure out how to extract the "with_backtrace:" here
      #
      # m = /^expected (.*?), got (.*?)(\s+with backtrace:)?/.match(line)
      if ! unescaped_line.strip.empty?
        expected_and_got_match = /^expected\s+(.*?), got\s+(.*)/.match(unescaped_line)
        if expected_and_got_match # we've exited the description
          require 'byebug'; byebug
          self.expected = expected_and_got_match[1]
          if expected_and_got_match[2].end_with?("with backtrace:")
            self.got = expected_and_got_match[2].sub(/\s+with backtrace:/, '')
            in_backtrace = true
            self.failure_notes << "comparison backtrace:"
          else
            self.got = expected_and_got_match[2]
          end
        elsif ! in_backtrace
          prefix, content = message_line_components(unescaped_line)
          if ! message_line_assignment_by_prefix(prefix, content, unescaped_line)
            # require 'byebug'; byebug
            self.description << line
          end
        else # backtrace line
          # require 'byebug'; byebug
          self.failure_notes << unescaped_line.sub(/^# /, '')
        end
      end
    end
  end

  def extract_line_number(path_with_line_number)
    m = /.*:(\d+)$/.match(path_with_line_number)
    m.nil? ? nil : m[1].to_i
  end

  def extract_failure_location(lines)
    lines.each do | line |
      m = /(.*(?<!_spec).rb):(\d+):in.*?`(.*)'/.match(line)
      if m
        self.error_file_path   = m[1]
        self.error_line_number = m[2]
        self.error_method      = m[3]
      end
    end
  end
end

class RtestFormatter
  # rspec 3.11 docs for making them
  # https://relishapp.com/rspec/rspec-core/v/3-11/docs/formatters/custom-formatters

  # register it with rspec, and tell it what notifications you want
  # https://www.rubydoc.info/gems/rspec-core/RSpec%2FCore%2FFormatters%2Eregister
  #  .register(formatter_class, *notifications) ⇒ void
  #
  #   formatter_class (Class) — formatter class to register
  #   notifications (Array<Symbol>) — one or more notifications to
  #     be registered to the specified formatter

  RSpec::Core::Formatters.register self,
                                   :example_failed,
                                   :close
  def initialize(output)
    @output = output
    @failures = []
  end

  # called if the example fails
  # notification: FailedExampleNotification
  # http://www.rubydoc.info/gems/rspec-core/RSpec/Core/Notifications/FailedExampleNotification
  def example_failed(notification)
    # FailedExampleNotification
    # colorizer param's unspecified default is ::RSpec::Core::Formatters::ConsoleCodes
    #
    #  - colorized_formatted_backtrace(colorizer) -> Array<String>
    #  - colorized_message_lines(colorizer) - Array<String>
    #  - description -> String
    #    "Multipart::Post::CompositeReadIO test_empty_parts"
    #  - example -> RSpec::Core::Example
    #    #<RSpec::Core::Example "test_empty_parts">
    #  - exception -> Exception
    #    #<RSpec::Expectations::ExpectationNotMetError:
    #      expected: == "INTENTIONAL FAILURE"
    #      got:    "ick">
    #    OR
    #    MultipleExpectationsNotMetError...
    #  - formatted_backtrace -> Array<String>
    #  - fully_formatted(failure_number, colorizer) -> String
    #  - fully_formatted_lines(failure_number, colorizer) -> Array<String>
    #  - message_lines -> Array<String>
    # #  ["Failure/Error: expect(io.read(3)).to be == \"INTENTIONAL FAILURE\"", "", "  expected: == \"INTENTIONAL FAILURE\"", "       got:    \"ick\""]
    #     FORMATTED:
    #     Failure/Error: expect(io.read(3)).to be == "INTENTIONAL FAILURE"
    #
    #       expected: == "INTENTIONAL FAILURE"
    #            got:    "ick"
    #
    ####
    # Notes:
    # notification.exception.message
    #   "expected: == \"INTENTIONAL FAILURE\"\n     got:    \"ick\""
    f = Failure.new(notification)
    @failures << f
  end


  # notification: NullNotification http://www.rubydoc.info/gems/rspec-core/RSpec/Core/Notifications/NullNotification
  def close(_)
    @output << "BEGIN_RTEST_JSON"
    @output << "\n[\n#{@failures.map{ |f|f.to_json }.join(",\n")}\n]"
  end
end
