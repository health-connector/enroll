module EmployerWorld
  def create_benefit_sponsorship(legal_name)
    create_site
    build_benefit_sponsorship(legal_name)
  end
  
  def add_employer_attestation(status)
    @employer_attestation ||= FactoryGirl.create(:employer_attestation,aasm_state:status,employer_profile:@employer_profile)
  end
end

World(EmployerWorld)

Given(/^there is an employer (.*?)$/) do |legal_name|
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
  create_benefit_sponsorship(@legal_name)
end

And(/^at least one attestation document status is (.*?)$/) do |status|
  add_employer_attestation(status)
end