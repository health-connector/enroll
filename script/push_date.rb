# frozen_string_literal: true

hbx_id = Rails.application.config.acapi.hbx_id
environment = Rails.application.config.acapi.environment_name
target_exchange = "#{hbx_id}.#{environment}.e.fanout.events"
# This publishes the date the system advances to, so it reads the clock rather
# than TimeKeeper. It has to be the exchange date, since the process runs in UTC
# and would otherwise advance a day early when it runs after the UTC day rolls.
current_date = TimeKeeper.date_according_to_exchange_at(Time.current).strftime("%Y-%m-%d")
event_routing_key = "info.events.calendar.date_change"

conn = Bunny.new(Rails.application.config.acapi.to_connection_settings)
conn.start
chan = conn.create_channel
chan.confirm_select
ex = chan.fanout(target_exchange, :durable => true)
ex.publish("", { :routing_key => event_routing_key, :headers => { "current_date" => current_date }})
chan.wait_for_confirms
conn.close
