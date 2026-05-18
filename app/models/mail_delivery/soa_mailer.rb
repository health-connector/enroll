module MailDelivery
  class SoaMailer
    include Acapi::Notifiers

    def initialize(*vals)
      # A slug because mail insists on invoking it
    end

    def deliver!(mail)
      subject = mail.subject
      body = mail.body.raw_source
      mail.to.each do |recipient|
        #I don't think this is the best solution but its the fastest solution
        subject = I18n.transliterate(subject) unless subject.blank?
        send_email_html(recipient, subject, body)
      end
    end
  end
end
