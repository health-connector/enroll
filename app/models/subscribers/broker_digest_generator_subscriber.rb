module Subscribers
  class BrokerDigestGeneratorSubscriber < ::Acapi::Subscription
    include Acapi::Notifiers

    def self.subscription_details
      ["acapi.info.events.broker.generate_broker_xml"]
    end

    def call(_event_name, _e_start, _e_end, _msg_id, _payload)
      views = Rails::Application::Configuration.new(Rails.root).paths["app/views"]
      views_helper = ActionView::Base.new views
      views_helper.class.send(:include, EventsHelper)

      tmp_path = if Rails.env.test?
                   FileUtils.mkdir_p("#{Rails.root}/tmp/broker_digest").first
                 else
                   Dir.mktmpdir
                 end

      tmp_zip_path = tmp_path + ".zip"

      Zip::File.open(tmp_zip_path, Zip::File::CREATE) do  |zipfile|
        zipfile.mkdir("broker_xmls")
        Person.where("broker_role.aasm_state" => "active").each do |individual|
          broker_digest = views_helper.render file: File.join(Rails.root, "/app/views/events/brokers/created"), :locals => {:individual => individual}
          zipfile.get_output_stream("broker_xmls/#{individual.broker_role.npn}.xml") {|os| os.write(broker_digest) }
        end
      end

      raw_broker_data = File.read(tmp_zip_path)
      @body = Base64.encode64(raw_broker_data)

      notify("acapi.info.events.brokers.broker_digest_published",
             {:body => @body,
              :return_status => "200"})
    rescue StandardError => e
      error_payload = JSON.dump({:error => e.inspect,
                                 :message => e.message,
                                 :backtrace => e.backtrace})
      notify("acapi.error.events.brokers.broker_digest_published.unknown_error", {:headers => {:return_status => "500", :body => error_payload}})
    ensure
      FileUtils.rm_rf(tmp_path)
      FileUtils.rm_rf(tmp_zip_path)
    end
  end
end
