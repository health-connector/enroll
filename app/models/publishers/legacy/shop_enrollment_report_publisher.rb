module Publishers
  class Legacy::ShopEnrollmentReportPublisher
    attr_reader :gateway
    def initialize
      @gateway = TransportGateway::Gateway.new(nil, Rails.logger)
    end

    def publish(file_uri)
      process = TransportProfiles::Processes::Legacy::PushShopEnrollmentReport.new(file_uri, @gateway)
      process.execute
    end
  end
end