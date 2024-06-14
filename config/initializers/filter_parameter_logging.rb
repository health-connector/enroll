# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [:password, :question_answer, :password_confirmation, :new_password, :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn]
