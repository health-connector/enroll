require File.join(Rails.root, "app", "data_migrations", "define_permissions")

#All hbx_roles can view families, employers, broker_agencies, brokers and general agencies
#The convention for a privilege group 'x' is  'modify_x', or view 'view_x'

namespace :permissions do
  desc 'define the permissions'
  DefinePermissions.define_task :initial_hbx => :environment
end

namespace :permissions do
  desc 'build test roles'
  DefinePermissions.define_task :build_test_roles => :environment
end

namespace :permissions do
  desc 'hbx admin can update ssn'
  DefinePermissions.define_task :hbx_admin_can_update_ssn => :environment
end

namespace :permissions do
  desc 'hbx admin can complete resident application'
  DefinePermissions.define_task :hbx_admin_can_complete_resident_application => :environment

  desc 'hbx admin can lock and unlock a user'
  DefinePermissions.define_task :hbx_admin_can_lock_unlock => :environment

  desc 'hbx admin can reset password a user'
  DefinePermissions.define_task :hbx_admin_can_reset_password => :environment
end

namespace :permissions do
  desc 'hbx admin can add sep'
  DefinePermissions.define_task :hbx_admin_can_add_sep => :environment
end

namespace :permissions do
  desc 'hbx admin can view username and email'
  DefinePermissions.define_task :hbx_admin_can_view_username_and_email => :environment
end

namespace :permissions do
  desc 'hbx admin can access user account tab'
  DefinePermissions.define_task :hbx_admin_can_access_user_account_tab => :environment
end

#RAILS_ENV=production bundle exec rake permissions:hbx_admin_can_change_fein
namespace :permissions do
  desc 'hbx system admin can change fein'
  DefinePermissions.define_task :hbx_admin_can_change_fein => :environment
end

# RAILS_ENV=production bundle exec rake permissions:hbx_admin_can_force_publish
namespace :permissions do
  desc 'hbx admin can force publish'
  DefinePermissions.define_task :hbx_admin_can_force_publish => :environment
end

# RAILS_ENV=production bundle exec rake permissions:hbx_admin_can_extend_open_enrollment
namespace :permissions do
  desc 'hbx admin can extend open enrollment'
  DefinePermissions.define_task :hbx_admin_can_extend_open_enrollment => :environment
end

# RAILS_ENV=production bundle exec rake permissions:hbx_admin_can_modify_plan_year
namespace :permissions do
  desc 'hbx admin can update plan years'
  DefinePermissions.define_task :hbx_admin_can_modify_plan_year => :environment
end

# RAILS_ENV=production bundle exec rake permissions:hbx_admin_can_create_benefit_application
namespace :permissions do
  desc 'hbx admin can create benefit application'
  DefinePermissions.define_task :hbx_admin_can_create_benefit_application => :environment
end

# RAILS_ENV=production bundle exec rake permissions:grant_super_admin_access user_email="<email address1>,<email address2>"
namespace :permissions do
  desc 'grant super admin access for given users'
  DefinePermissions.define_task :grant_super_admin_access => :environment
end

# RAILS_ENV=production bundle exec rake permissions:grant_hbx_tier3_access user_email="<email address1>,<email address2>"
namespace :permissions do
  desc 'grant hbx tier3 access for given users'
  DefinePermissions.define_task :grant_hbx_tier3_access => :environment
end

# RAILS_ENV=production bundle exec rake permissions:hbx_admin_can_update_enrollment_end_date_or_reinstate
namespace :permissions do
  desc 'hbx admin can create benefit application'
  DefinePermissions.define_task :hbx_admin_can_update_enrollment_end_date_or_reinstate => :environment
end

#RAILS_ENV=production bundle exec rake permissions:hbx_admin_can_change_username_and_email
namespace :permissions do
  desc 'hbx super admin can change username and email'
  DefinePermissions.define_task :hbx_admin_can_change_username_and_email => :environment
end

#RAILS_ENV=production bundle exec rake permissions:hbx_admin_view_login_history
namespace :permissions do
  desc 'hbx super admin can view login history'
  DefinePermissions.define_task :hbx_admin_view_login_history => :environment
end

#RAILS_ENV=production bundle exec rake permissions:hbx_admin_can_view_notice_templates
namespace :permissions do
  desc 'hbx admin can view notice templates'
  DefinePermissions.define_task :hbx_admin_can_view_notice_templates => :environment
end

#RAILS_ENV=production bundle exec rake permissions:hbx_admin_can_edit_notice_templates
namespace :permissions do
  desc 'hbx admin can edit notice templates'
  DefinePermissions.define_task :hbx_admin_can_edit_notice_templates => :environment
end

#RAILS_ENV=production bundle exec rake permissions:hbx_admin_can_update_pvp_eligibilities
namespace :permissions do
  desc 'hbx admin can mark pvp eligibilities'
  DefinePermissions.define_task :hbx_admin_can_update_pvp_eligibilities => :environment
end

#rake permissions:initial_hbx
#rake permissions:migrate_hbx
#rake permissions:hbx_admin_can_update_ssn
#rake permissions:hbx_admin_can_complete_resident_application
#rake permissions:hbx_admin_can_access_user_account_tab
#rake permissions:hbx_admin_can_update_ssn
#rake permissions:hbx_admin_can_reset_password
#rake permissions:hbx_admin_can_modify_plan_year
