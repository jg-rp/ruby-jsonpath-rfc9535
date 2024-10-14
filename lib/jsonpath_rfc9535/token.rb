# frozen_string_literal: true

require_relative "errors"

module JsonpathRfc9535
  class Span
    # @dynamic start, stop
    attr_reader :start
    attr_reader :stop

    def initialize(start, stop)
      @start = start
      @stop = stop
    end
  end

  class Token
    EOI = :token_eoi
    ERROR = :token_error

    SHORTHAND_NAME = :token_shorthand_name
    COLON = :token_colon
    COMMA = :token_comma
    DOT = :token_dot
    DOUBLE_DOT = :token_double_dot
    FILTER = :token_filter
    INDEX = :token_index
    LBRACKET = :token_lbracket
    NAME = :token_name
    RBRACKET = :token_rbracket
    ROOT = :token_root
    WILD = :token_wild

    AND = :token_and
    CURRENT = :token_current
    DOUBLE_QUOTE_STRING = :token_double_quote_string
    EQ = :token_eq
    FALSE = :token_false
    FLOAT = :token_float
    FUNCTION = :token_function
    GE = :token_ge
    GT = :token_gt
    INT = :token_int
    LE = :token_le
    LPAREN = :token_lparen
    LT = :token_lt
    NE = :token_ne
    NOT = :token_not
    NULL = :token_null
    OP = :token_op
    OR = :token_or
    RPAREN = :token_rparen
    SINGLE_QUOTE_STRING = :token_single_quote_string
    TRUE = :token_true

    # @dynamic type, value
    attr_reader :type, :value

    def initialize(type, value, span, query)
      @type = type
      @value = value
      @span = span
      @query = query
    end

    def ==(other)
      self.class == other.class && @type == other.type && @value == other.value
    end

    alias eql? ==

    def hash
      @type.hash ^ @value.hash
    end

    def deconstruct
      [@type, @value]
    end

    def deconstruct_keys(_)
      { type: @type, value: @value }
    end

    def expect(token_type)
      return if token_type == @type

      raise JSONPathSyntaxError.new("expected #{token_type}, found #{@type}", self)
    end
  end
end
