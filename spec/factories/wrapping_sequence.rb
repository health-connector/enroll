# frozen_string_literal: true

class WrappingSequence

  def initialize(start_at, wrap_after)
    @start_at = start_at
    @value = @start_at
    @wrap_max = wrap_after
  end

  def next
    @value = if @value == @wrap_max
               @start_at
             else
               @value + 1
             end
  end

  def peek
    @value
  end
end
