class Stream
  class EOF
    def empty?
      true
    end

    def +(other_stream)
      other_stream
    end

    def to_a
      []
    end

    def method_missing(*)
      self
    end

    def respond_to_missing?(*)
      true
    end
  end

  def self.emit(*args, &block)
    if block_given?
      raise ArgumentError unless args.empty?

      Stream.new(
        block,
        lambda { empty }
      )
    else
      raise ArgumentError unless args.size == 1

      Stream.new(
        lambda { args[0] },
        lambda { empty }
      )  
    end
  end

  def self.emits(enumerable)
    return empty unless enumerable.any?

    Stream.new(
      lambda { enumerable.first },
      lambda { Stream.emits(_tail_for_enumerable(enumerable)) }
    )
  end

  def self.empty
    EOF.new
  end

  def initialize(head_func, tail_func)
    @head_func = head_func
    @tail_func = tail_func
  end

  def head
    @head ||= @head_func.call
  end

  def tail
    @tail ||= @tail_func.call
  end

  def empty?
    head.instance_of?(EOF)
  end

  def +(other_stream)
    return other_stream if empty?

    Stream.new(
      @head_func,
      lambda { tail + other_stream }
    )
  end

  def to_a
    [].tap do |arr|
      each do |element|
        arr << element
      end
    end
  end

  def flat_map(&block)
    return self if empty?

    if head.is_a?(Stream)
      Stream.new(
        lambda { block.call(head.head) },
        lambda { head.tail.map(&block) + tail.flat_map(&block) }
      )
    else
      Stream.new(
        lambda { block.call(head) },
        lambda { tail.flat_map(&block) }
      )
    end
  end

  def map(&block)
    Stream.new(
      lambda { block.call(head) },
      lambda { tail.map(&block) }
    )
  end

  def flatten
    flat_map(&:itself)
  end

  def each(&block)
    pointer = self

    until pointer.empty?
      block.call(pointer.head)
      pointer = pointer.tail
    end
  end

  def take(n)
    raise ArgumentError unless n >= 0

    return Stream.empty if empty? || n == 0

    Stream.new(
      @head_func,
      lambda { tail.take(n - 1) }
    )
  end

  def drop(n)
    raise ArgumentError unless n >= 0

    return Stream.empty if empty?
    return self if n == 0

    tail.drop(n - 1)
  end

  def repeat
    Stream.new(
      @head_func,
      lambda { tail + self.repeat }
    )
  end

  def filter(&block)
    if block.call(head)
      Stream.new(
        @head_func,
        lambda { tail.filter(&block) }
      )
    else
      tail.filter(&block)
    end
  end

  private

  def self._tail_for_enumerable(enumerable)
    if enumerable.is_a?(Range)
      new_start = enumerable.first.succ

      if enumerable.exclude_end?
        new_start...enumerable.end
      else
        new_start..enumerable.end
      end
    else
      enumerable.drop(1)
    end
  end
end
