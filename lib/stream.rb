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

  def self.emit(value)
    Stream.new(
      lambda { value },
      lambda { EOF.new }
    )
  end

  def self.emits(enumerable)
    return EOF.new unless enumerable.any?

    Stream.new(
      lambda { enumerable.first },
      lambda { Stream.emits(_tail_for_enumerable(enumerable)) }
    )
  end

  def self.empty
    Stream.emit(nil).tail
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
      pointer = self

      until pointer.empty?
        arr << pointer.head
        pointer = pointer.tail
      end
    end
  end

  def flat_map(&block)
    return self if empty?

    if head.is_a?(Stream)
      Stream.new(
        lambda { block.call(head.head) },
        lambda { Stream.emit(head.tail).flat_map(&block) + tail.flat_map(&block) }
      )
    else
      Stream.new(
        lambda { block.call(head) },
        lambda { tail.flat_map(&block) }
      )
    end
  end

  def map(&block)
    Stream.emit(self).flat_map(&block)
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
