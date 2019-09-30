# frozen_string_literal: true

require 'tempfile'

module Subscribers
  class BrokerDigestGeneratorSubscriber
    include Acapi::Notifiers

    def self.worker_specification
      Acapi::Amqp::WorkerSpecification.new(
        :queue_name => "broker_digest_generator_subscriber",
        :kind => :direct,
        :routing_key => "info.events.broker.generate_broker_xml"
      )
    end

    def work_with_params(_body, _delivery_info, _properties)
      tmp_zip_file = nil
      begin
        renderer = ApplicationController.new

        tmp_zip_file = Tempfile.create("enroll_broker_digest_zip")
        tmp_zip_file.close

        Zip::File.open(tmp_zip_file.path, Zip::File::CREATE) do  |zipfile|
          zipfile.mkdir("broker_xmls")
          Person.where("broker_role.aasm_state" => "active").each do |individual|
            broker_digest = renderer.render_to_string({
              template: 'events/brokers/created',
              formats: [:xml],
              layout: false,
              locals: {:individual => individual}
            })
            zipfile.get_output_stream("broker_xmls/#{individual.broker_role.npn}.xml") do |os|
              os.write(broker_digest)
            end
          end
        end

        raw_broker_data = File.read(tmp_zip_file.path)
        @body = Base64.encode64(raw_broker_data)

        notify("acapi.info.events.brokers.broker_digest_published",
               {:body => @body,
                :return_status => "200"})
      rescue StandardError => e
        error_payload = JSON.dump({:error => e.inspect,
                                   :message => e.message,
                                   :backtrace => e.backtrace})
        notify("acapi.error.events.brokers.broker_digest_published.unknown_error", {:headers => {:return_status => "500", :body => error_payload}})
        return :reject
      ensure
        if tmp_zip_file
          FileUtils.rm_rf(tmp_zip_file.path)
        end
      end

      :ack
    end
  end
end
