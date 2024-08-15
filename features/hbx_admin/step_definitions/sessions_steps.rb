# frozen_string_literal: true

Given(/^that a user with a HBX staff role with (.*) subrole exists$/) do |subrole|
  p_staff = if ['super_admin', 'hbx_tier3'].include?(subrole)
              Permission.create(name: subrole,
                                modify_family: true, modify_employer: true, revert_application: true, list_enrollments: true,
                                send_broker_agency_message: true, approve_broker: true, approve_ga: true, can_update_ssn: true,
                                can_complete_resident_application: true, can_add_sep: true, can_lock_unlock: true,
                                can_view_username_and_email: true, can_reset_password: true,
                                modify_admin_tabs: true, view_admin_tabs: true, can_extend_open_enrollment: true, view_the_configuration_tab: true,
                                can_submit_time_travel_request: false, can_change_username_and_email: true, view_login_history: true)
            else
              Permission.create(name: subrole, modify_family: true, modify_employer: true, revert_application: true,
                                list_enrollments: true, send_broker_agency_message: true, approve_broker: true, approve_ga: true, can_update_ssn: true,
                                can_complete_resident_application: false, can_add_sep: false, can_lock_unlock: true,
                                can_view_username_and_email: true, can_reset_password: false, can_extend_open_enrollment: true, view_the_configuration_tab: true,
                                modify_admin_tabs: true, view_admin_tabs: true,   can_submit_time_travel_request: false, can_change_username_and_email: true,
                                view_login_history: true)
            end
  person = people['Hbx Admin']
  hbx_profile = FactoryBot.create(:hbx_profile)
  user = FactoryBot.create(:user, :with_family, :hbx_staff, email: person[:email], password: person[:password], password_confirmation: person[:password])
  FactoryBot.create(:hbx_staff_role, person: user.person, hbx_profile: hbx_profile, permission_id: p_staff.id)
  FactoryBot.create(:hbx_enrollment, household: user.primary_family.active_household)
end

Given(/^the prevent_concurrent_sessions feature is (.*)?/) do |is_enabled|
  is_enabled == "enabled" ? enable_feature(:prevent_concurrent_sessions) : disable_feature(:prevent_concurrent_sessions)
end

# rubocop:disable Style/GlobalVars
Given(/^admin logs in on browser (.*)?/) do |session_id|
  in_session(session_id) do
    person = people["Hbx Admin"]
    session = $sessions[session_id]
    session.visit "/users/sign_in"
    session.fill_in SignIn.username, :with => person[:email]
    session.find('#user_login').set(person[:email])
    session.fill_in SignIn.password, :with => person[:password]
    session.fill_in SignIn.username, :with => person[:email] unless session.find(:xpath, '//*[@id="user_login"]').value == person[:email]
    session.find(".interaction-click-control-sign-in", wait: 5).click
  end
end

And(/^admin attempts to navigate on browser (.*)?/) do |session_id|
  in_session(session_id) do
    session = $sessions[session_id]
    session.visit exchanges_hbx_profiles_root_path
  end
end

Then(/^admin on browser (.*) should (.*) the logged out due to concurrent session message?/) do |session_id, visibility|
  in_session(session_id) do
    session = $sessions[session_id]
    if visibility == "see"
      expect(session).to have_content(l10n('devise.sessions.signed_out_concurrent_session'))
    else
      expect(session).not_to have_content(l10n('devise.sessions.signed_out_concurrent_session'))
    end
  end
end
# rubocop:enable Style/GlobalVars
