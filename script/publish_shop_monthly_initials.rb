environment_name = 'prod'
target_exchange = "ma0.#{environment_name}.e.fanout.events"
effective_on_date = "2017-05-01"
event_routing_key = "info.events.employer.binder_enrollments_transmission_authorized"

new_employer_feins = %w(

)

conn = Bunny.new(Rails.application.config.acapi.to_connection_settings)
conn.start
chan = conn.create_channel
chan.confirm_select
ex = chan.fanout(target_exchange, :durable => true) 
new_employer_feins.each do |fein|
 ex.publish(
   "",
   {
     :routing_key => event_routing_key,
     :headers => {
       "fein" => fein.strip,
       "effective_on" => effective_on_date
     }
   }
 )
 chan.wait_for_confirms
end
conn.close
