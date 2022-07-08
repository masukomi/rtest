# frozen_string_literal: true

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
    self.failure_notes  = []
    self.description    = []
    @meta_backtrace = []

    example = notification.example

    extract_attrs_from_example(example)
    extract_attrs_from_notification(notification)
    incorporate_meta_backtrace
    extract_failure_location(filtered_backtrace)
  end

  # removes gems, rspec, and bundle lines from your backtrace
  # This, of course, presumes you're not actually editing one
  # of those.
  def filtered_backtrace
    elliptified_lines = backtrace.map { |line| filterable_line?(line) ? '…' : line }
    returnable_lines = []
    elliptified_lines.each_with_index do |line, idx|
      if line != '…' && idx != 0
        returnable_lines << line
      elsif idx.positive? \
            && !returnable_lines.empty? \
            && returnable_lines.last != '…'
        returnable_lines << line
      end
    end
    return returnable_lines if returnable_lines.last != '…'

    returnable_lines[0..-2]
  end

  def filterable_line?(line)
    line.include?('/lib/ruby/') \
      || line.include?('/bin/rspec') \
      || line.include?('/bin/bundle') \
      || line.include?('/spec_helper.rb')
  end

  def to_json(*_args)
    hash = {}
    instance_variables.map { |x| x.to_s.sub('@', '').to_sym }.each do |method|
      hash[method] = send(method) unless %i[meta_backtrace backtrace].include? method
    end
    hash[:backtrace] = filtered_backtrace

    JSON.pretty_generate(hash)
  end

  def inspect
    to_json
  end

  protected

  def incorporate_meta_backtrace
    return true if @meta_backtrace.empty?

    # self.backtrace = @meta_backtrace.map { |b| "meta: #{b}" } + backtrace
    self.backtrace = @meta_backtrace + backtrace
    @meta_backtrace = []
  end

  def unescape(text)
    # return '' if text.nil?
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
    extract_message_elements(notification)
    process_backtrace(notification.formatted_backtrace || [])
  end

  # this is a... sub-optimal test.
  # I just don't have a better idea yet
  def line_is_path?(line)
    !! (line.split(File::SEPARATOR).size > 1 && %r{^\s*\.?/}.match(line))
  end

  def process_backtrace(notification_backtrace)
    temp_backtrace = []
    # sometimes backtrace is more than backtrace. For example
    # "backtrace": [
    #   "KeyError:",
    #   "  Foo::Bar: option 'user_baz' is required",
    #   "(eval):5:in `block in __dry_initializer_initialize__'",
    #   "(eval):5:in `fetch'",
    #   "(eval):5:in `__dry_initializer_initialize__'",
    #   "./actual/path/to/foo_spec.rb:9:in `new'",
    #   "./more/actua/backtrace..."
    notification_backtrace.each do |line|
      if line_is_path?(line)
        temp_backtrace << line
      else
        failure_notes << line
      end
    end
    self.backtrace = temp_backtrace
  end

  def extract_message_elements(notification)
    lines = notification
            .colorized_message_lines # .map{ |line| unescape(line.sub(/^\s+/, '')) }
            .reject { |line| unescape(line).empty? }
    # sholud be [failure/error, expected, got, <optional comparison note>]
    # but i don't want to assume

    return false if lines.empty?

    complex_extraction = unescape(lines.first) == 'Failure/Error:' \
                         || lines.any? { |line| !!/^expected .*?, got /.match(unescape(line)) }
    if complex_extraction
      complex_message_extraction(lines)
    else
      simple_message_extraction(lines)
    end
  end

  def simple_message_extraction(lines)
    in_syntax_error = false
    lines.each do |line|
      unescaped_line = unescape(line)
      components = message_line_components(unescaped_line)
      result = message_line_assignment_by_prefix(components, line, in_syntax_error)
      in_syntax_error = (result == :syntax ? true : false)
    end
  end

  def message_line_assignment_by_prefix(components, line, in_syntax_error = false)
    unescaped_line = unescape(line)
    return false if unescaped_line.strip.empty?

    did_something = false
    #                    key-v  value-v
    components.each do |prefix, content|
      if in_syntax_error
        if line_is_path?(prefix)
          add_meta_backtrace_line(prefix)
          did_something = true
        end
      elsif prefix == 'Failure/Error'
        description << content
        did_something = true
      elsif prefix == 'SyntaxError'
        description << prefix
        did_something = :syntax
      elsif prefix == 'expected'
        self.expected = content
        did_something = true
      elsif prefix == 'got'
        self.got = content
        did_something = true
      else
        # it's a non-blank line with content that isn't one of the above...
        if meta_backtrace_line?(unescaped_line)
          # they start with "    # ./lib/..."
          add_meta_backtrace_line(unescaped_line)
        else
          failure_notes << line
        end
        did_something = true
      end
    end
    did_something
  end

  def add_meta_backtrace_line(unescaped_line)
    @meta_backtrace << unescaped_line.sub(/^\s*#\s+/, '')
  end

  # assumes we've been passed a non-null unescaped_line
  def meta_backtrace_line?(unescaped_line)
    !!%r{^\s*#\s+\.?/}.match(unescaped_line) || line_is_path?(unescaped_line)
  end

  def message_line_components(line)
    # presumes an unescaped line
    # prefix, content
    m = /expected (.*?), got (.*?)(\s+with backtrace:)/.match(line)
    if m
      {
        'expected' => m[1],
        'got' => m[2]
      }
    else
      { line.sub(/^\s*(\S+.*):.*/, '\1') => line.sub(/^.*?:\s*/, '') }
    end
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

    in_backtrace = false
    # 1st line is useless
    return if lines.size == 1 ## theoretically can't happen

    lines[1..-1].each_with_index do |line, _index|
      unescaped_line = unescape(line)

      next if unescaped_line.strip.empty?

      components = message_line_components(unescaped_line)
      has_expected_or_got  = (components.keys & %w[expected got]).size.positive?
      if has_expected_or_got
        self.expected = components['expected'] if components.key? 'expected'
        self.got      = components['got']      if components.key? 'got'
      end

      if !in_backtrace && unescaped_line.end_with?('with backtrace:')
        in_backtrace = true
        next
      elsif has_expected_or_got
        next
      end


      if in_backtrace
        if meta_backtrace_line?(unescaped_line)
          add_meta_backtrace_line(unescaped_line)
        else
          # not sure if this is actually a thing or not.
          failure_notes << unescaped_line
        end
      end
    end
  end

  def extract_line_number(path_with_line_number)
    m = /.*:(\d+)$/.match(path_with_line_number)
    m.nil? ? nil : m[1].to_i
  end

  def extract_failure_location(lines)
    syntax_error = description.any?{|x| x == 'SyntaxError'}

    lines.each do |line|
      if ! syntax_error
        m = /(.*(?<!_spec)\.rb):(\d+):in.*?`(.*)'/.match(line)
        next unless m

        self.error_file_path   = m[1]
        self.error_line_number = m[2]
        self.error_method      = m[3]
        break
      else
        m = /(.*\.rb):(\d+)/.match(line) # it could be in a spec file
        next unless m

        self.error_file_path   = m[1]
        self.error_line_number = m[2]
        self.error_method      = "SYNTAX ERROR"
        break
      end
    end

  end
end

class Message < Failure

  def initialize(notification)
    self.expected         = nil
    self.got              = nil
    self.spec_line_number = nil
    self.rspec_arg        = nil
    self.run_time         = 0
    self.spec_file_path   = nil
    self.spec_location    = nil
    self.test_name        = nil

    self.failure_notes  = []
    self.description    = []
    self.backtrace = []
    @meta_backtrace = []

    # things we can extract
    # backtrace
    # description
    # failure_notes
    # error_file_path
    # error_line_number
    # error_method
    # failure_notes
    message_lines = notification.message.split("\n")
    simple_message_extraction(message_lines)
    incorporate_meta_backtrace
    extract_failure_location(self.backtrace)
  end

  def just_run_options?
    return failure_notes.first.start_with?("Run options:")
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
                                   :close,
                                   :message
  def initialize(output)
    @output = output
    @failures = []
  end
  def message(notification)
    m = Message.new(notification)
    @failures << m unless m.just_run_options?
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
    @output << 'BEGIN_RTEST_JSON'
    @output << "\n[\n#{@failures.map(&:to_json).join(",\n")}\n]"
  end
end
