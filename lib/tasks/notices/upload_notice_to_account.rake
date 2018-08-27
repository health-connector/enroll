# Rake task used to upload notices to employer accounts
# To run rake task: RAILS_ENV=production bundle exec rake migrations:upload_notice_to_account profile="employer" fein="987654321" notice_name="Special Enrollment Denial Notice" file_path="lib/special_enrollment_denial_notice.pdf"

# Rake task used to upload notices to employees accounts
# To run rake task: RAILS_ENV=production bundle exec rake migrations:upload_notice_to_account profile="employee" hbx_id="987654321" notice_name="Special Enrollment Denial Notice" file_path="lib/special_enrollment_denial_notice.pdf"

require File.join(Rails.root, "app", "data_migrations", "upload_notice_to_account")

namespace :migrations do
  desc "Uploading notices to employer account"
  UploadNoticeToAccount.define_task :upload_notice_to_account => :environment
end
