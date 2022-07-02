# frozen_string_literal: true

require_relative "../constants"
module Rtest
  module Common
    def unescape(text)
      text.gsub(ANSI_MATCHER, '')
    end
  end
end
