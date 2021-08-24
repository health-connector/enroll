# frozen_string_literal: true

module SoaMailable
  extend ActiveSupport::Concern

  def initialize(*vals)
    # A slug because mail insists on invoking it
  end

  def deliver!(mail)
    subject = mail.subject
    body = mail.body.raw_source
    mail.to.each do |recipient|
      # https://stackoverflow.com/a/20586777/5331859
      # Will transliterate any special latin accent marks
      # into regular latin characters
      # I18n.transliterate("Text with speceial accent marks")
      # Converts to a string without accent marks
      # => "Instrucciones de recuperacion de contrasena"
      subject = I18n.transliterate(subject) unless subject.blank?
      send_email_html(recipient, subject, body)
    end
  end
end