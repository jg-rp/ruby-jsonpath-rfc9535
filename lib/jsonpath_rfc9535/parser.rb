# frozen_string_literal: true

require_relative "errors"
require_relative "function"
require_relative "segment"
require_relative "selector"
require_relative "token"

module JsonpathRfc9535
  # Step through tokens
  class Stream
    def initialize(tokens)
      @it = tokens.to_enum
      @eoi = tokens.last
    end

    def next
      @it.next
    rescue StopIteration
      @eor
    end

    def peek
      @it.peek
    rescue StopIteration
      @eor
    end

    def expect(token_type)
      return if peek.type == token_type

      token = self.next
      raise JSONPathSyntaxError.new("expected #{token_type}, found #{token}", token)
    end

    def expect_not(token_type, message)
      return unless peek.type == token_type

      token = self.next
      raise JSONPathSyntaxError.new(message, token)
    end
  end

  # A JSONPath expression parser.
  class Parser # rubocop:disable Metrics/ClassLength
    def initialize(env)
      @env = env
    end

    # Parse an array of tokens into an abstract syntax tree.
    # @param tokens [Array<Token>] tokens from the lexer.
    # @return [Array<Segment>]
    def parse(tokens)
      stream = Stream.new(tokens)
      stream.expect(Token::ROOT)
      stream.next
      parse_query(stream)
    end

    protected

    def parse_query(stream) # rubocop:disable Metrics/MethodLength
      segments = []

      loop do
        case stream.peek.type
        when Token::DOUBLE_DOT
          token = stream.next
          selectors = parse_selectors(stream)
          segments << RecursiveDescentSegment.new(@env, token, selectors)
        when Token::LBRACKET, Token::NAME, Token::WILD
          token = stream.peek
          selectors = parse_selectors(stream)
          segments << ChildSegment.new(@env, token, selectors)
        else
          break
        end
      end

      segments
    end

    def parse_selectors(stream) # rubocop:disable Metrics/MethodLength
      case stream.peek.type
      when Token::NAME
        token = stream.next
        [NameSelector.new(@env, token, token.value)]
      when Token::WILD
        [WildcardSelector.new(@env, stream.next)]
      when Token::LBRACKET
        parse_bracketed_selection(stream)
      else
        []
      end
    end

    def parse_bracketed_selection(stream) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
      stream.expect Token::LBRACKET
      segment_token = stream.next

      selectors = []

      loop do # rubocop:disable Metrics/BlockLength
        case stream.peek.type
        when Token::RBRACKET
          break
        when Token::Index
          selectors << parse_index_or_slice(stream)
        when Token::DOUBLE_QUOTE_STRING, Token::SINGLE_QUOTE_STRING
          token = stream.next
          selectors << NameSelector.new(@env, token, decode_string_literal(token))
        when Token::COLON
          selectors << parse_slice_selector(stream)
        when Token::WILD
          selectors << WildcardSelector.new(@env, stream.next)
        when Token::FILTER
          selectors << parse_filter_selector(stream)
        when Token::EOI
          raise JSONPathSyntaxError.new("unexpected end of query", stream.next)
        else
          raise JSONPathSyntaxError.new("unexpected token in bracketed selection", stream.next)
        end

        case stream.peek.type
        when Token::EOI
          raise JSONPathSyntaxError.new("unexpected end of selector list", stream.next)
        when Token::RBRACKET
          break
        else
          stream.expect Token::COMMA
          stream.next
          stream.expect_not(Token::RBRACKET, "unexpected trailing comma")
        end
      end

      raise JSONPathSyntaxError("empty segment", segment_token) if selectors.empty?

      selectors
    end

    def parse_index_or_slice(stream) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      token = stream.next
      index = parse_i_json_int(token)

      return IndexSelector.new(@env, token, index) unless stream.peek.type == Token::COLON

      stream.next # move past colon
      stop = nil
      step = nil

      case stream.peek.type
      when Token::INT
        stop = parse_i_json_int(stream.next)
      when Token::COLON
        stream.next # move past colon
      end

      case stream.peek.type
      when Token::INT
        step = parse_i_json_int(stream.next)
      else
        error_token = stream.next
        raise JSONPathSyntaxError("expected a slice, found '#{token.value}'", error_token)
      end

      SliceSelector.new(@env, token, index, stop, step)
    end

    def parse_slice_selector(stream) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      stream.expect(Token::COLON)
      token = stream.next

      start = nil
      stop = nil
      step = nil

      case stream.peek.type
      when Token::INT
        stop = parse_i_json_int(stream.next)
      when Token::COLON
        stream.next # move past colon
      end

      case stream.peek.type
      when Token::INT
        step = parse_i_json_int(stream.next)
      else
        error_token = stream.next
        raise JSONPathSyntaxError("expected a slice, found '#{token.value}'", error_token)
      end

      SliceSelector.new(@env, token, start, stop, step)
    end

    def parse_filter_selector(_stream)
      raise "not implemented"
    end

    def parse_i_json_int(token)
      # TODO: int check range
      if token.value.length > 1 && token.value.starts_with("0", "-0")
        raise JSONPathSyntaxError("invalid index '#{token.value}'", token)
      end

      token.value.to_i
    end
  end
end
