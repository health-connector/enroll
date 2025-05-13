# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "layouts/_header.html.erb", :dbclean => :around_each do

  let(:person_user) { FactoryBot.create(:person) }
  let(:current_user) { FactoryBot.create(:user, :person => person_user)}
  let(:site) { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let(:benefit_sponsor) { FactoryBot.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
  let(:employer_profile) { benefit_sponsor.employer_profile }
  let(:active_employer_staff_role) { FactoryBot.create(:benefit_sponsor_employer_staff_role, person: person_user, aasm_state: 'is_active', benefit_sponsor_employer_profile_id: employer_profile.id)}
  let(:broker_agency_profile) { FactoryBot.create(:broker_agency_profile)}
  let(:broker_role) { FactoryBot.build(:broker_role, broker_agency_profile_id: broker_agency_profile.id, benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id) }
  let(:signed_in?) { true }

  #let!(:byline) { create(:translation, key: "en.layouts.header.byline", value: Settings.site.header_message) }
  before do
    Translation.create(key: "en.welcome.index.byline", value: "\"#{Settings.site.header_message}\"")
  end
  before(:each) do
    sign_in current_user
  end
  it 'identifies HBX Staff' do
    current_user.roles = ['hbx_staff']
    current_user.save
    render :template => 'layouts/_header'
    expect(rendered).to match(/I'm an Admin/)
  end
  it 'identifies Brokers' do
    broker_person = FactoryBot.create(:person, :with_broker_role)
    broker_role = broker_person.broker_role
    broker_role.broker_agency_profile_id = broker_agency_profile.id
    broker_role.benefit_sponsors_broker_agency_profile_id = broker_agency_profile.id
    broker_role.save!
    broker_user = FactoryBot.create(:user, person: broker_person, roles: ['broker'])
    
    # Sign in as the broker
    sign_in broker_user
    render :template => 'layouts/_header'
    expect(rendered).to match(/I'm a Broker/)
  end
  it 'identifies Employers' do
    allow(person_user).to receive(:employer_staff_roles).and_return([active_employer_staff_role])
    allow(controller).to receive(:controller_path).and_return("employer_profiles")
    current_user.roles = ['employer_staff']
    current_user.save
    allow_any_instance_of(User).to receive(:has_employer_staff_role?).and_return(true)
    render :template => 'layouts/_header'
    expect(rendered).to match(/I'm an Employer/)
  end

  it 'identifies Customer Service Staff' do
    person_user.csr_role = FactoryBot.build(:csr_role, cac: false)
    current_user.roles = ['csr']
    render :template => 'layouts/_header'
    expect(rendered).to match(/I'm a Trained Expert/)
  end

  it 'identifies Certified Applicant Counselor' do
    person_user.csr_role = FactoryBot.build(:csr_role, cac: true)
    current_user.roles = ['csr']
    render :template => 'layouts/_header'
    expect(rendered).to match(/I'm a Trained Expert/)
  end

  it 'identifies Assisters' do
    current_user.roles = ['assister']
    current_user.person.assister_role = FactoryBot.build(:assister_role)
    render :template => 'layouts/_header'
    expect(rendered).to match(/I'm a Trained Expert/)
  end

  it 'identifies default controller' do
    render :template => 'layouts/_header'
    expect(rendered).to match(/#{Settings.site.header_message}/)
  end

end
