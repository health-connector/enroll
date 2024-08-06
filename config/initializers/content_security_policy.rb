# frozen_string_literal: true
# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

Rails.application.config.content_security_policy do |policy|
  policy.default_src :self, :https
  policy.font_src :self, :https, :data, "*.gstatic.com  *.fontawesome.com"
  policy.img_src :self, :https, :data, "*.google-analytics.com *.gstatic.com *.googletagmanager.com"
  policy.script_src :self, :https, :unsafe_inline, :unsafe_eval, "https://tagmanager.google.com https://www.googletagmanager.com https://apps.usw2.pure.cloud *.fontawesome.com *.google-analytics.com"
  policy.style_src :self, :https, :unsafe_inline, "https://tagmanager.google.com https://www.googletagmanager.com https://fonts.googleapis.com *.fontawesome.com"
  policy.media_src :self, :https, :data
end

# If you are using UJS then enable automatic nonce generation
# Rails.application.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }

# Report CSP violations to a specified URI
# For further information see the following documentation:
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy-Report-Only
# Rails.application.config.content_security_policy_report_only = true
