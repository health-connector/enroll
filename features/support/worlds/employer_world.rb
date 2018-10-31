module EmployerWorld
  
  def employer(profile=nil)
    @organization ||= FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site)
  end
end

World(EmployerWorld)

And(/^there is an employer (.*?)$/) do |legal_name|
  @legal_name = legal_name
end

And(/^this employer has a (.*?) benefit application$/) do |status|
  case status
  when "draft"
    @state = :with_aca_shop_cca_employer_profile_initial_application
  when "renewal"
    @state = :with_renewal_benefit_application
  when "expired"
    @state = :with_expired_and_active_benefit_application
  end
  benefit_sponsorship(employer)
end

And(/^at least one attestation document status is (.*?)$/) do |status|
  @employer_attestation_status = status
end