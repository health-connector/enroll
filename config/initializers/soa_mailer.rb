Rails.application.config.to_prepare do
  ActionMailer::Base.add_delivery_method :soa_mailer, MailDelivery::SoaMailer
end