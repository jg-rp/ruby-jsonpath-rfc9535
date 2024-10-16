# frozen_string_literal: true

require_relative "../function"

module JsonpathRfc9535
  # The standard `count` function.
  class Match < FunctionExtension
    ARG_TYPES = [ExpressionType::VALUE, ExpressionType::VALUE].freeze
    RETURN_TYPE = ExpressionType::LOGICAL

    def call(string, pattern)
      raise "not implemented"
    end
  end
end