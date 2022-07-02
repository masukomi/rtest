    # SET UP THE COLORS
    BACKTRACE_COLOR = "\e[38;2;127;128;128m"
    COLOR_RESET = "\e[0m"
    FAILURE_NOTE_LINE_COLOR = ''
    DETAIL_LINE_COLOR = "\e[38;2;255;140;0m"
    ERROR_HERE_LINE_COLOR = "\e[1;38;5;7m" # "\e[100,37m"
    ERROR_LINE_COLOR = "\e[38;5;196m"
    EXPECTED_LINE_COLOR = "\e[32m"
    FILE_HIGHLIGHT_COLOR = "\e[38;5;7m"
    GOT_LINE_COLOR = "\e[38;2;255;110;103m" # "\e[91m"
    LINE_NUMBER_COLOR = "\e[38;5;214m" # was 100;33
    SUCCESS_COLOR = "\e[38;2;7;198;25m"

    RTEST_DIR = __dir__

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

    NO_FAILURES_TEXT = "\n✅ No failures."
    NO_TESTS_RUN_TEXT = "\n -----------------------------------------------\n⚠️   NOTE: This is only a replay of past output."

    PAST_RUN_FILENAME = '.rtest.json'

