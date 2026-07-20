# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [:password, :question_answer, :password_confirmation, :new_password, :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :dob, :new_dob, :date_of_birth, :birth_date,
                                               :employer_attestation_id, :employers_action_id, :employer_actions_id, :family_actions_id]
