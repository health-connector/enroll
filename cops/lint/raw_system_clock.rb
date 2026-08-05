module RuboCop
  module Cop
    module Lint
      # Reads of the process clock follow the server time zone rather than the
      # exchange calendar. The application derives its business day from
      # TimeKeeper, so a script run from a console and the application itself can
      # disagree about what day it is, and they do disagree every evening between
      # the start of the UTC day and midnight Eastern.
      #
      # Use TimeKeeper.date_of_record when the value means "what day is it for
      # the business". Use Time.current when the value is a real timestamp, such
      # as when it is being written to a created_at or submitted_at field.
      #
      # @example
      #   # bad
      #   Date.today
      #   Time.now
      #   DateTime.now
      #
      #   # good
      #   TimeKeeper.date_of_record
      #   Time.current
      class RawSystemClock < Base
        MSG = 'Avoid `%<source>s`, it follows the server clock. Use `TimeKeeper.date_of_record` for a business date or `Time.current` for a timestamp.'.freeze

        RESTRICT_ON_SEND = %i[now today].freeze

        def_node_matcher :raw_system_clock?, <<~PATTERN
          {(send (const {nil? cbase} :Time) :now)
           (send (const {nil? cbase} :Date) :today)
           (send (const {nil? cbase} :DateTime) :now)}
        PATTERN

        def on_send(node)
          return unless raw_system_clock?(node)

          add_offense(node, message: format(MSG, :source => node.source))
        end
      end
    end
  end
end
