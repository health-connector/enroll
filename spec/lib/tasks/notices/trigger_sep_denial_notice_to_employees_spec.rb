require 'rails_helper'
require 'rake'

describe 'triggering SEP denial notice to employees', :dbclean => :around_each do
  describe 'notice:trigger_sep_denial_notice_to_employees' do

    let(:current_effective_date)  { TimeKeeper.date_of_record }
    let(:site)                { create(:benefit_sponsors_site, :with_benefit_market, :as_hbx_profile, :cca) }
    let!(:benefit_market_catalog) { create(:benefit_markets_benefit_market_catalog, :with_product_packages,
                                            benefit_market: benefit_market,
                                            title: "SHOP Benefits for #{current_effective_date.year}",
                                            application_period: (current_effective_date.beginning_of_year..current_effective_date.end_of_year))
                                          }
    let(:benefit_market)      { site.benefit_markets.first }
    let!(:product_package) { benefit_market_catalog.product_packages.first }

    let!(:rating_area)   { FactoryGirl.create_default :benefit_markets_locations_rating_area }
    let!(:service_area)  { FactoryGirl.create_default :benefit_markets_locations_service_area }
    let!(:security_question)  { FactoryGirl.create_default :security_question }

    let(:organization) { FactoryGirl.create(:benefit_sponsors_organizations_general_organization, :with_aca_shop_cca_employer_profile, site: site) }
    let!(:employer_attestation)     { BenefitSponsors::Documents::EmployerAttestation.new(aasm_state: "approved") }
    let(:benefit_sponsorship) do
      FactoryGirl.create(
        :benefit_sponsors_benefit_sponsorship,
        :with_rating_area,
        :with_service_areas,
        supplied_rating_area: rating_area,
        service_area_list: [service_area],
        organization: organization,
        profile_id: organization.profiles.first.id,
        benefit_market: site.benefit_markets[0],
        employer_attestation: employer_attestation)
    end

    let(:start_on)  { current_effective_date.prev_month }
    let(:effective_period)  { start_on..start_on.next_year.prev_day }
    let!(:benefit_application) {
      application = FactoryGirl.create(:benefit_sponsors_benefit_application, :with_benefit_sponsor_catalog, benefit_sponsorship: benefit_sponsorship, effective_period: effective_period, aasm_state: :active)
      application.benefit_sponsor_catalog.save!
      application
    }

    let!(:benefit_package) { FactoryGirl.create(:benefit_sponsors_benefit_packages_benefit_package, benefit_application: benefit_application, product_package: product_package) }
    let(:benefit_group_assignment) {FactoryGirl.build(:benefit_sponsors_benefit_group_assignment, benefit_group: benefit_package)}

    let(:employee_role) { FactoryGirl.create(:benefit_sponsors_employee_role, person: person, employer_profile: benefit_sponsorship.profile, census_employee_id: census_employee.id) }
    let(:census_employee) { FactoryGirl.create(:benefit_sponsors_census_employee,
      employer_profile: benefit_sponsorship.profile,
      benefit_sponsorship: benefit_sponsorship,
      benefit_group_assignments: [benefit_group_assignment]
    )}
    let(:person) { FactoryGirl.create(:person, hbx_id: '765487') }
    let!(:family) { FactoryGirl.create(:family, :with_primary_family_member, person: person)}

    let!(:hbx_enrollment) do
      FactoryGirl.create(:hbx_enrollment,
                         household: family.active_household,
                         kind: "employer_sponsored",
                         effective_on: start_on,
                         employee_role_id: employee_role.id,
                         sponsored_benefit_package_id: benefit_package.id,
                         benefit_group_assignment_id: benefit_group_assignment.id,
                         aasm_state: 'coverage_selected'
      )
    end
    let(:file_path) { "spec/test_data/notices/sep_denial_notice_test_data" }
    let(:qle)       { FactoryGirl.build(:qualifying_life_event_kind, market_kind: "shop") }

    before do
      allow(QualifyingLifeEventKind).to receive(:find).and_return(qle)
    end

    it 'should trigger SEP denial notice to employee' do
      census_employee.class.observer_peers.keys.each do |observer|
        expect(observer).to receive(:notifications_send) do |instance, model_event|
          expect(model_event).to be_an_instance_of(BenefitSponsors::ModelEvents::ModelEvent)
          expect(model_event).to have_attributes(:event_key => :employee_notice_for_sep_denial, :klass_instance => census_employee, :options => {:qle_title=>"Married", :qle_reporting_deadline=>"07/11/2018", :qle_event_on=>"06/11/2018"})
        end
      end
      load File.expand_path("#{Rails.root}/lib/tasks/notices/trigger_sep_denial_notice_to_employees.rake", __FILE__)
      Rake::Task.define_task(:environment)
      Rake::Task["notice:trigger_sep_denial_notice_to_employees"].invoke("#{file_path}")
    end
  end
end
