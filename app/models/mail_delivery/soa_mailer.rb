module MailDelivery
  class SoaMailer
    include Acapi::Notifiers
    include SoaMailable
  end
end
