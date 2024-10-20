# frozen_string_literal: true

module JSONPathRFC9535
  # Base class for all JSONPath selectors
  class Selector
    # @dynamic token
    attr_reader :token

    def initialize(env, token)
      @env = env
      @token = token
    end

    # Apply this selector to _node_.
    # @return [Array<JSONPathNode>]
    def resolve(_node)
      raise "selectors must implement resolve(node)"
    end

    # Return true if this selector is a singular selector.
    def singular?
      false
    end
  end

  # The name selector select values from hashes given a key.
  class NameSelector < Selector
    # @dynamic name
    attr_reader :name

    def initialize(env, token, name)
      super(env, token)
      @name = name
    end

    def resolve(node)
      [node.new_child(node.value.fetch(@name), @name)]
    rescue IndexError, TypeError, NoMethodError
      []
    end

    def singular?
      true
    end

    def to_s
      @name.inspect
    end

    def ==(other)
      self.class == other.class &&
        @name == other.name &&
        @token == other.token
    end

    alias eql? ==

    def hash
      [@name, @token].hash
    end
  end

  # The index selector selects values from arrays given an index.
  class IndexSelector < Selector
    # @dynamic index
    attr_reader :index

    def initialize(env, token, index)
      super(env, token)
      @index = index
    end

    def resolve(node)
      [node.new_child(node.value.fetch(@index), normalize(@index, node.value.length))]
    rescue IndexError, TypeError, NoMethodError, RangeError
      # NOTE: RangeError has only occured when testing with truffleruby
      []
    end

    def singular?
      true
    end

    def to_s
      @index.to_s
    end

    def ==(other)
      self.class == other.class &&
        @index == other.index &&
        @token == other.token
    end

    alias eql? ==

    def hash
      [@index, @token].hash
    end

    private

    def normalize(index, length)
      index.negative? && length >= index.abs ? length + index : index
    end
  end

  # The wildcard selector selects all elements from an array or values from a hash.
  class WildcardSelector < Selector
    def resolve(node)
      if node.value.is_a? Hash
        node.value.map { |k, v| node.new_child(v, k) }
      elsif node.value.is_a? Array
        node.value.map.with_index { |e, i| node.new_child(e, i) }
      else
        []
      end
    end

    def to_s
      "*"
    end

    def ==(other)
      self.class == other.class && @token == other.token
    end

    alias eql? ==

    def hash
      @token.hash
    end
  end

  # The slice selector selects a range of elements from an array.
  class SliceSelector < Selector
    # @dynamic start, stop, step
    attr_reader :start, :stop, :step

    def initialize(env, token, start, stop, step)
      super(env, token)
      @start = start
      @stop = stop
      @step = step
    end

    def resolve(node) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      return [] unless node.value.is_a?(Array)

      length = node.value.length
      step = @step || 1
      return [] if length.zero? || step.zero?

      start = if @start.nil?
                step.negative? ? length - 1 : 0
              elsif @start.negative?
                [length + @start, 0].max
              else
                [@start, length - 1].min
              end

      stop = if @stop.nil?
               step.negative? ? -1 : length
             elsif @stop.negative?
               [length + @stop, -1].max
             else
               [@stop, length].min
             end

      if step.positive?
        node.value[(start...stop).step(step)].map.with_index do |e, i|
          node.new_child(e, i)
        end
      else
        nodes = []
        i = start
        while i > stop
          nodes << node.new_child(node.value[i], i)
          i += step
        end
        nodes
      end
    end

    def to_s
      start = @start || ""
      stop = @stop || ""
      step = @step || 1
      "#{start}:#{stop}:#{step}"
    end

    def ==(other)
      self.class == other.class &&
        @start == other.start &&
        @stop == other.stop &&
        @step == other.step &&
        @token == other.token
    end

    alias eql? ==

    def hash
      [@start, @stop, @step, @token].hash
    end

    private

    def normalized_index(index, length)
      index.negative? && length >= index.abs ? length + index : index
    end
  end

  # Select array elements or hash values according to a filter expression.
  class FilterSelector < Selector
    # @dynamic expression
    attr_reader :expression

    def initialize(env, token, expression)
      super(env, token)
      @expression = expression
    end

    def resolve(node) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      nodes = []

      if node.value.is_a?(Array)
        node.value.each_with_index do |e, i|
          context = FilterContext.new(@env, e, node.root)
          nodes << node.new_child(e, i) if @expression.evaluate(context)
        end
      elsif node.value.is_a?(Hash)
        node.value.each_pair do |k, v|
          context = FilterContext.new(@env, v, node.root)
          nodes << node.new_child(v, k) if @expression.evaluate(context)
        end
      end

      nodes
    end

    def to_s
      "?#{@expression}"
    end

    def ==(other)
      self.class == other.class &&
        @expression == other.start &&
        @token == other.token
    end

    alias eql? ==

    def hash
      [@expression, @token].hash
    end
  end
end
