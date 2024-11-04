class ApplicationMailer < ActionMailer::Base

  include Config::SiteHelper

  default from: "#{mail_address}"

  if Rails.env.production?
    self.delivery_method = :soa_mailer
  end

  def notice_email(notice)
    mail({ to: notice.to, subject: notice.subject}) do |format|
      format.html { notice.html }
    end
  end

  def sanitize_email(email)
    email.gsub(::User::HEX_ESCAPE_REGEX, '')
  end

  def mail(headers = {}, &block)
    headers[:to] = sanitize_email(headers[:to]) if headers[:to].present?
    super
  end
end
