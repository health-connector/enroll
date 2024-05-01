require "rails_helper"

describe FamilyPolicy, "given a user who has no properties" do
  let(:primary_person_id) { double }
  let(:family) { instance_double(Family) }
  let(:user) { instance_double(User, :person => nil) }

  subject { FamilyPolicy.new(user, family) }

  it "can't show" do
    expect(subject.legacy_show?).to be_falsey
  end
end

describe FamilyPolicy, "given a user who is the primary member" do
  let(:primary_person_id) { double }
  let(:family) { instance_double(Family, :primary_applicant => primary_member) }
  let(:person) { instance_double(Person, :id => primary_person_id) }
  let(:user) { instance_double(User, :person => person) }
  let(:primary_member) { instance_double(FamilyMember, :person_id => primary_person_id) }

  subject { FamilyPolicy.new(user, family) }

  it "can show" do
    expect(subject.legacy_show?).to be_truthy
  end
end

describe FamilyPolicy, "given a family with an active broker agency account", :dbclean => :after_each do
  let(:person) { FactoryGirl.create(:person, :with_family)}
  let(:family) { (person.primary_family) }
  let(:site)  { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let(:broker_agency_profile) { FactoryGirl.create(:benefit_sponsors_organizations_broker_agency_profile, market_kind: 'shop', legal_name: 'Legal Name1', assigned_site: site) }
  let(:broker_role) { FactoryGirl.create(:broker_role, aasm_state: 'active', benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id ) }
  let(:broker_agency_account) {FactoryGirl.create(:broker_agency_account, broker_agency_profile_id: broker_agency_profile_id_account, writing_agent_id: broker_role.id, is_active: true)}

  subject { FamilyPolicy.new(user, family) }

  describe "when the user is an active member of the same broker agency as the account" do
    let(:broker_agency_profile_id_account) { broker_agency_profile.id }
    let(:user) { FactoryGirl.create(:user, :person => person)}

    it "can show" do
      expect(subject.legacy_show?).to be_truthy
    end
  end

  describe "when the user is an active member of a different broker agency from the account" do
    let(:broker_agency_profile_id_account) { double }
    let(:broker_person) { broker_role.person }
    let(:user) { FactoryGirl.create(:user, :person => broker_person)}

    it "can't show" do
      expect(subject.legacy_show?).to be_falsey
    end
  end
end

describe FamilyPolicy, "given a family where the primary has an active employer broker account", dbclean: :after_each do
  let(:site)  { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
  let(:organization)        { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
  let(:employer_profile)    { organization.employer_profile }
  let(:employee_role) {FactoryGirl.create(:employee_role, employer_profile: employer_profile)}
  let(:person) { FactoryGirl.create(:person, :with_family)}
  let(:family) { (person.primary_family) }
  let(:broker_agency_profile) { FactoryGirl.create(:benefit_sponsors_organizations_broker_agency_profile, market_kind: 'shop', legal_name: 'Legal Name1', assigned_site: site) }
  let(:broker_role) { FactoryGirl.create(:broker_role, aasm_state: 'active', benefit_sponsors_broker_agency_profile_id: broker_agency_profile.id ) }
  let(:broker_agency_account) {FactoryGirl.create(:broker_agency_account, broker_agency_profile_id: broker_agency_profile_id_account, writing_agent_id: broker_role.id, is_active: true)}

  subject { FamilyPolicy.new(user, family) }

  describe "when the user is an active member of the same broker agency as the account" do
    let(:broker_agency_profile_id_account) { broker_agency_profile.id }
    let(:user) { FactoryGirl.create(:user, :person => person)}

    it "can show" do
      expect(subject.legacy_show?).to be_truthy
    end
  end

  describe "when the user is an active member of a different broker agency from the account" do
    let(:broker_agency_profile_id_account) { double }
    let(:employee_person) { employee_role.person }
    let(:user) { FactoryGirl.create(:user, :person => employee_person)}

    it "can't show" do
      expect(subject.legacy_show?).to be_falsey
    end
  end
end

describe FamilyPolicy, "given a family where the primary has an active employer general agency account account" do
  let(:primary_person_id) { double }
  let(:ga_person_id) { double }
  let(:general_agency_profile_id) { double }
  let(:family) { instance_double(Family, :primary_applicant => primary_member, :active_broker_agency_account => nil) }
  let(:employer_profile) { instance_double(EmployerProfile, :active_broker_agency_account => nil, :active_general_agency_account => general_agency_account) }
  let(:employee_role) { instance_double(EmployeeRole, :employer_profile => employer_profile) }
  let(:person) { instance_double(Person, :id => primary_person_id, :active_employee_roles => [employee_role]) }
  let(:user) { instance_double(User, :person => ga_person) }
  let(:ga_person) { instance_double(Person, :id => ga_person_id, :broker_role => nil, :active_general_agency_staff_roles => [general_agency_staff_role], :hbx_staff_role => nil) }
  let(:general_agency_staff_role) { instance_double(GeneralAgencyStaffRole, :general_agency_profile_id => general_agency_profile_id) }
  let(:general_agency_account) { instance_double(GeneralAgencyAccount, :general_agency_profile_id => general_agency_account_profile_id ) }
  let(:primary_member) { instance_double(FamilyMember, :person_id => primary_person_id, :person => person) }

  subject { FamilyPolicy.new(user, family) }

  describe "when the user is an active member of the same general agency as the account" do
    let(:general_agency_account_profile_id) { general_agency_profile_id }

    it "can show" do
      expect(subject.legacy_show?).to be_truthy
    end
  end

  describe "when the user is an active member of a different general agency from the account" do
    let(:general_agency_account_profile_id) { double }

    it "can't show" do
      expect(subject.legacy_show?).to be_falsey
    end
  end
end

describe FamilyPolicy, "given a user who has the modify family permission" do
  let(:primary_person_id) { double }
  let(:family) { instance_double(Family, :primary_applicant => primary_member, :active_broker_agency_account => nil) }
  let(:person) { instance_double(Person, :id => primary_person_id) }
  let(:user) { instance_double(User, :person => permissioned_person) }
  let(:permissioned_person) { instance_double(Person, :id => double, :hbx_staff_role => hbx_staff_role) }
  let(:primary_member) { instance_double(FamilyMember, :person_id => primary_person_id, :person => person) }
  let(:hbx_staff_role) { instance_double(HbxStaffRole, :permission => permission) }
  let(:permission) { instance_double(Permission, :modify_family => true) }

  subject { FamilyPolicy.new(user, family) }

  it "can show" do
    expect(subject.legacy_show?).to be_truthy
  end
end


RSpec.describe FamilyPolicy, type: :policy do
  context 'user with permission' do
    let(:hbx_profile) { FactoryGirl.create(:hbx_profile)}
    let(:person) { FactoryGirl.create(:person, :with_employee_role)}
    let(:user) { FactoryGirl.create(:user, person: person) }
    let!(:family) { FactoryGirl.create(:family, :with_primary_family_member, person: person) }

    before do
      allow(person).to receive(:user).and_return(user)
      allow(person).to receive(:primary_family).and_return family
    end

    context 'user with hbx_staff_role roles' do

      shared_examples_for "logged in user has hbx admin role" do |policy_type|
        let(:admin_person) { FactoryGirl.create(:person, :with_hbx_staff_role) }
        let(:admin_user) { FactoryGirl.create(:user, :with_hbx_staff_role, person: admin_person) }
        let(:permission) { FactoryGirl.create(:permission, :super_admin) }
        let!(:update_admin) { admin_person.hbx_staff_role.update_attributes(permission_id: permission.id) }
        let(:policy) { FamilyPolicy.new(admin_user, family)}

        it 'hbx_staff with super_admin permission' do
          expect(policy.send(policy_type)).to be true
        end
      end

      it_behaves_like 'logged in user has hbx admin role', :show?
      it_behaves_like 'logged in user has hbx admin role', :home?
      it_behaves_like 'logged in user has hbx admin role', :manage_family?
      it_behaves_like 'logged in user has hbx admin role', :brokers?
      it_behaves_like 'logged in user has hbx admin role', :find_sep?
      it_behaves_like 'logged in user has hbx admin role', :personal?
      it_behaves_like 'logged in user has hbx admin role', :inbox?
      it_behaves_like 'logged in user has hbx admin role', :verification?
      it_behaves_like 'logged in user has hbx admin role', :upload_application?
      it_behaves_like 'logged in user has hbx admin role', :check_qle_date?
      it_behaves_like 'logged in user has hbx admin role', :purchase?
      it_behaves_like 'logged in user has hbx admin role', :upload_notice?
      it_behaves_like 'logged in user has hbx admin role', :upload_notice_form?
    end

    context 'user with employee role' do
      shared_examples_for "logged in user has employee role" do |policy_type|
        let(:policy) { FamilyPolicy.new(user, family)}

        it 'employee role permission' do
          expect(policy.send(policy_type)).to be true
        end
      end

      it_behaves_like 'logged in user has employee role', :show?
      it_behaves_like 'logged in user has employee role', :home?
      it_behaves_like 'logged in user has employee role', :manage_family?
      it_behaves_like 'logged in user has employee role', :brokers?
      it_behaves_like 'logged in user has employee role', :find_sep?
      it_behaves_like 'logged in user has employee role', :personal?
      it_behaves_like 'logged in user has employee role', :inbox?
      it_behaves_like 'logged in user has employee role', :verification?
      it_behaves_like 'logged in user has employee role', :check_qle_date?
      it_behaves_like 'logged in user has employee role', :purchase?
    end
  end
end
