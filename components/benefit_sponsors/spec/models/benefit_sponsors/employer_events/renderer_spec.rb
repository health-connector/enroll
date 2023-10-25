# frozen_string_literal: true

require "rails_helper"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

describe BenefitSponsors::EmployerEvents::Renderer, "given an xml, from which it selects carrier plan years", :dbclean => :after_each do
  let(:event_time) { double }

  let(:carrier) { instance_double(BenefitSponsors::Organizations::IssuerProfile, :hbx_carrier_id => hbx_carrier_id) }

  let(:source_document) do
    <<-XMLCODE
		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
			<plan_year>
				<plan_year_start>20151201</plan_year_start>
				<plan_year_end>20161130</plan_year_end>
				<open_enrollment_start>20151013</open_enrollment_start>
				<open_enrollment_end>20151110</open_enrollment_end>
				<benefit_groups>
					<benefit_group>
						<name>Health Insurance</name>
						<elected_plans>
							<elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>SOME CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
						</elected_plans>
					</benefit_group>
				</benefit_groups>
       </plan_year>
     </plan_years>
    XMLCODE
  end

  let(:employer_event) { instance_double(BenefitSponsors::Services::EmployerEvent, {:event_time => event_time, :resource_body => source_document}) }

  subject do
    BenefitSponsors::EmployerEvents::Renderer.new(employer_event)
  end

  let(:carrier_plan_years) { subject.carrier_plan_years(carrier) }

  describe "with plan years for the specified carrier" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }

    it "finds plan years for the carrier" do
      expect(carrier_plan_years).not_to be_empty
    end

    it "has the correct element in scope" do
      carrier_plan_years.to_a.map(&:name)
    end
  end

  describe "with no plan years for the specified carrier" do
    let(:hbx_carrier_id) { "A DIFFERENT CARRIER ID" }

    it "finds plan years for the carrier" do
      expect(carrier_plan_years).to be_empty
    end
  end
end

describe BenefitSponsors::EmployerEvents::Renderer, "given an xml, with an event type of benefit_coverage_renewal_carrier_dropped" do
  let(:event_time) { double }
  let(:employer_event) { instance_double(BenefitSponsors::Services::EmployerEvent, {:event_time => event_time, :event_name => BenefitSponsors::EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT, :resource_body => source_document}) }

  let(:carrier) { instance_double(BenefitSponsors::Organizations::IssuerProfile, :hbx_carrier_id => hbx_carrier_id) }
  let(:plan_year_start) { Date.today + 1.day }

  let(:plan_year_end) { plan_year_start + 1.year - 1.day }

  let(:source_document) do
    <<-XMLCODE
		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
			<plan_year>
				<plan_year_start>#{plan_year_start.strftime('%Y%m%d')}</plan_year_start>
				<plan_year_end>#{plan_year_end.strftime('%Y%m%d')}</plan_year_end>
				<open_enrollment_start>20151013</open_enrollment_start>
				<open_enrollment_end>20151110</open_enrollment_end>
				<benefit_groups>
					<benefit_group>
						<name>Health Insurance</name>
						<elected_plans>
							<elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>SOME CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
						</elected_plans>
					</benefit_group>
				</benefit_groups>
       </plan_year>
     </plan_years>
    XMLCODE
  end

  subject do
    BenefitSponsors::EmployerEvents::Renderer.new(employer_event)
  end

  describe "with plan years for the specified carrier, in the future" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today + 1.day }

    it "is an invalid carrier drop event" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_truthy
    end

    it "is not an invalid renewal event" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end

  describe "with plan years for the specified carrier, in the past" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today - 1.day }

    it "is NOT an invalid carrier drop event" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_falsey
    end

    it "is not an invalid renewal event" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end
end

describe BenefitSponsors::EmployerEvents::Renderer, "given an xml, with an event type of benefit_coverage_renewal_application_eligible" do
  let(:event_time) { double }
  let(:employer_event) { instance_double(BenefitSponsors::Services::EmployerEvent, {:event_time => event_time, :event_name => BenefitSponsors::EmployerEvents::EventNames::RENEWAL_SUCCESSFUL_EVENT, :resource_body => source_document}) }

  let(:carrier) { instance_double(BenefitSponsors::Organizations::IssuerProfile, :hbx_carrier_id => hbx_carrier_id) }

  let(:plan_year_end) { plan_year_start + 1.year - 1.day }

  let(:source_document) do
    <<-XMLCODE
		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
			<plan_year>
				<plan_year_start>#{plan_year_start.strftime('%Y%m%d')}</plan_year_start>
				<plan_year_end>#{plan_year_end.strftime('%Y%m%d')}</plan_year_end>
				<open_enrollment_start>20151013</open_enrollment_start>
				<open_enrollment_end>20151110</open_enrollment_end>
				<benefit_groups>
					<benefit_group>
						<name>Health Insurance</name>
						<elected_plans>
							<elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>SOME CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
						</elected_plans>
					</benefit_group>
				</benefit_groups>
       </plan_year>
     </plan_years>
    XMLCODE
  end

  subject do
    BenefitSponsors::EmployerEvents::Renderer.new(employer_event)
  end

  describe "with plan years for the specified carrier, in the future" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today + 1.day }

    it "is NOT an invalid carrier drop event" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_falsey
    end

    it "is not an invalid renewal event" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end

  describe "with plan years for the specified carrier, in the past" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today - 1.day }

    it "is an invalid renewal event" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_truthy
    end

    it "is NOT an invalid carrier drop event" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_falsey
    end
  end
end

describe BenefitSponsors::EmployerEvents::Renderer, "given an xml" do
  let(:event_time) { double }
  let(:employer_event) { instance_double(BenefitSponsors::Services::EmployerEvent, {:event_time => event_time, :event_name => BenefitSponsors::EmployerEvents::EventNames::RENEWAL_SUCCESSFUL_EVENT, :resource_body => source_document}) }

  let(:carrier) { instance_double(BenefitSponsors::Organizations::IssuerProfile, :hbx_carrier_id => hbx_carrier_id) }

  let(:plan_year_end) { plan_year_start + 1.year - 1.day }

  let(:source_document) do
    <<-XMLCODE
		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
			<plan_year>
				<plan_year_start>#{plan_year_start.strftime('%Y%m%d')}</plan_year_start>
				<plan_year_end>#{plan_year_end.strftime('%Y%m%d')}</plan_year_end>
				<open_enrollment_start>20151013</open_enrollment_start>
				<open_enrollment_end>20151110</open_enrollment_end>
				<benefit_groups>
					<benefit_group>
						<name>Health Insurance</name>
						<elected_plans>
							<elected_plan>
								<id>
									<id>A HIOS ID</id>
								</id>
								<name>A PLAN NAME</name>
								<active_year>2015</active_year>
								<is_dental_only>false</is_dental_only>
								<carrier>
									<id>
										<id>SOME CARRIER ID</id>
									</id>
									<name>A CARRIER NAME</name>
								</carrier>
							</elected_plan>
						</elected_plans>
					</benefit_group>
				</benefit_groups>
       </plan_year>
     </plan_years>
    XMLCODE
  end

  subject do
    BenefitSponsors::EmployerEvents::Renderer.new(employer_event)
  end

  describe "with plan years for the specified carrier, which starts in the future" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today + 1.day }

    it "has a current or future plan year" do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_truthy
    end
  end

  describe "with plan years for the specified carrier, which starts today" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today }

    it "has a current or future plan year" do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_truthy
    end
  end

  describe "with plan years for the specified carrier, which ends in the future" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today - 1.year + 2.days }
    let(:plan_year_end) { Date.today + 1.day }

    it "has a current or future plan year" do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_truthy
    end
  end

  describe "with plan years for the specified carrier, which ends today" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today - 1.year + 1.day }
    let(:plan_year_end) { Date.today }

    it "has a current plan or future plan year" do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_truthy
    end
  end

  describe "with plan years for the specified carrier, which ends in the past" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today - 1.year }
    let(:plan_year_end) { Date.today - 1.day }

    it "has no current plan or future plan year" do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_falsey
    end
  end

  describe "with plan years for a different carrier, which starts in the future" do
    let(:hbx_carrier_id) { "SOME OTHER CARRIER ID" }
    let(:plan_year_start) { Date.today + 1.day }

    it "has no current or future plan year" do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_falsey
    end
  end
end

describe BenefitSponsors::EmployerEvents::Renderer, "given an plan year cancelation xml, with an event type of benefit_coverage_renewal_carrier_dropped" do
  let(:event_time) { double }
  let(:employer_event) { instance_double(BenefitSponsors::Services::EmployerEvent, {:event_time => event_time, :event_name => BenefitSponsors::EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT, :resource_body => source_document}) }

  let(:carrier) { instance_double(BenefitSponsors::Organizations::IssuerProfile, :hbx_carrier_id => hbx_carrier_id) }

  let(:source_document) do
    <<-XMLCODE
 		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
 			<plan_year>
 				<plan_year_start>#{plan_year_start.strftime('%Y%m%d')}</plan_year_start>
 				<plan_year_end>#{plan_year_end.strftime('%Y%m%d')}</plan_year_end>
 				<open_enrollment_start>20151013</open_enrollment_start>
 				<open_enrollment_end>20151110</open_enrollment_end>
 				<benefit_groups>
 					<benefit_group>
 						<name>Health Insurance</name>
 						<elected_plans>
 							<elected_plan>
 								<id>
 									<id>A HIOS ID</id>
 								</id>
 								<name>A PLAN NAME</name>
 								<active_year>2015</active_year>
 								<is_dental_only>false</is_dental_only>
 								<carrier>
 									<id>
 										<id>SOME CARRIER ID</id>
 									</id>
 									<name>A CARRIER NAME</name>
 								</carrier>
 							</elected_plan>
 						</elected_plans>
 					</benefit_group>
 				</benefit_groups>
        </plan_year>
      </plan_years>
    XMLCODE
  end

  subject do
    BenefitSponsors::EmployerEvents::Renderer.new(employer_event)
  end

  describe "with plan years for the specified carrier, with plan year start date == end date", :dbclean => :after_each do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today.beginning_of_month }
    let(:plan_year_end) { Date.today.beginning_of_month }

    it "should return true for carrier drop event with canceled plan year" do
      expect(subject.should_send_retroactive_term_or_cancel?(carrier)).to be_truthy
    end

    it "should return false if has canceled plan year " do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false if has canceled plan year" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false if has canceled plan year" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end

  describe "with plan years for the specified carrier, drop event with future plan year" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }

    let(:plan_year_start) {  Date.today.next_month.beginning_of_month }
    let(:plan_year_end) {  plan_year_start + 1.year - 1.day }


    it "should return false for carrier drop event without canceled plan year" do
      expect(subject.should_send_retroactive_term_or_cancel?(carrier)).to be_falsey
    end

    it "should return true " do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_truthy
    end

    it "should return true" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_truthy
    end

    it "should return false" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end
end

describe BenefitSponsors::EmployerEvents::Renderer, "given an xml for ineligble not renewing group, with an event type of benefit_coverage_renewal_carrier_dropped" do
  let(:event_time) { double }
  let(:employer_event) { instance_double(BenefitSponsors::Services::EmployerEvent, {:event_time => event_time, :event_name => BenefitSponsors::EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT, :resource_body => source_document}) }

  let(:carrier) { instance_double(BenefitSponsors::Organizations::IssuerProfile, :hbx_carrier_id => hbx_carrier_id) }

  let(:source_document) do
    <<-XMLCODE
 		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
 			<plan_year>
 				<plan_year_start>#{plan_year_start.strftime('%Y%m%d')}</plan_year_start>
 				<plan_year_end>#{plan_year_end.strftime('%Y%m%d')}</plan_year_end>
 				<open_enrollment_start>20151013</open_enrollment_start>
 				<open_enrollment_end>20151110</open_enrollment_end>
 				<benefit_groups>
 					<benefit_group>
 						<name>Health Insurance</name>
 						<elected_plans>
 							<elected_plan>
 								<id>
 									<id>A HIOS ID</id>
 								</id>
 								<name>A PLAN NAME</name>
 								<active_year>2015</active_year>
 								<is_dental_only>false</is_dental_only>
 								<carrier>
 									<id>
 										<id>SOME CARRIER ID</id>
 									</id>
 									<name>A CARRIER NAME</name>
 								</carrier>
 							</elected_plan>
 						</elected_plans>
 					</benefit_group>
 				</benefit_groups>
        </plan_year>
      </plan_years>
    XMLCODE
  end

  subject do
    BenefitSponsors::EmployerEvents::Renderer.new(employer_event)
  end

  describe "with plan years for the specified carrier, with drop plan year event & end date in past" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) {  (Date.today.prev_month.end_of_month - 1.year) + 1.day }
    let(:plan_year_end) { Date.today.prev_month.end_of_month }

    it "should return true for carrier drop event with ineligible plan year" do
      expect(subject.should_send_retroactive_term_or_cancel?(carrier)).to be_truthy
    end

    it "should return false if has ineligible plan year " do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false if has ineligible plan year" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false if has ineligible plan year" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end

  describe "with plan years for the specified carrier, drop event with future plan year" do
    let(:hbx_carrier_id) { "SOME CARRIER ID" }

    let(:plan_year_start) {  Date.today.next_month.beginning_of_month }
    let(:plan_year_end) {  plan_year_start + 1.year - 1.day }


    it "should return false for carrier drop event with ineligible plan year" do
      expect(subject.should_send_retroactive_term_or_cancel?(carrier)).to be_falsey
    end

    it "should return true " do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_truthy
    end

    it "should return true" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_truthy
    end

    it "should return false" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end
end

describe BenefitSponsors::EmployerEvents::Renderer, "given an termianation xml, with an nonpayment/voltunary termination event" do
  let(:event_time) { double }
  let(:carrier) { instance_double(BenefitSponsors::Organizations::IssuerProfile, :hbx_carrier_id => hbx_carrier_id) }

  let(:source_document) do
    <<-XMLCODE
 		<plan_years xmlns="http://openhbx.org/api/terms/1.0">
 			<plan_year>
 				<plan_year_start>#{plan_year_start.strftime('%Y%m%d')}</plan_year_start>
 				<plan_year_end>#{plan_year_end.strftime('%Y%m%d')}</plan_year_end>
 				<open_enrollment_start>20151013</open_enrollment_start>
 				<open_enrollment_end>20151110</open_enrollment_end>
 				<benefit_groups>
 					<benefit_group>
 						<name>Health Insurance</name>
 						<elected_plans>
 							<elected_plan>
 								<id>
 									<id>A HIOS ID</id>
 								</id>
 								<name>A PLAN NAME</name>
 								<active_year>2015</active_year>
 								<is_dental_only>false</is_dental_only>
 								<carrier>
 									<id>
 										<id>SOME CARRIER ID</id>
 									</id>
 									<name>A CARRIER NAME</name>
 								</carrier>
 							</elected_plan>
 						</elected_plans>
 					</benefit_group>
 				</benefit_groups>
        </plan_year>
      </plan_years>
    XMLCODE
  end

  describe "with plan years for the specified carrier, with benefit_coverage_period_terminated_voluntary event" do

    let(:employer_event) { instance_double(BenefitSponsors::Services::EmployerEvent, {:event_time => event_time, :event_name => "benefit_coverage_period_terminated_voluntary", :resource_body => source_document}) }

    subject do
      BenefitSponsors::EmployerEvents::Renderer.new(employer_event)
    end

    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today.beginning_of_month - 10.month }
    let(:plan_year_end) {  (plan_year_start + 8.month).end_of_month }

    it "should return true if terminated plan year present" do
      expect(subject.should_send_retroactive_term_or_cancel?(carrier)).to be_truthy
    end

    it "should return false " do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end

  describe "with plan years for the specified carrier, with benefit_coverage_period_terminated_nonpayment event" do

    let(:employer_event) { instance_double(BenefitSponsors::Services::EmployerEvent, {:event_time => event_time, :event_name => "benefit_coverage_period_terminated_nonpayment", :resource_body => source_document}) }

    subject do
      BenefitSponsors::EmployerEvents::Renderer.new(employer_event)
    end

    let(:hbx_carrier_id) { "SOME CARRIER ID" }
    let(:plan_year_start) { Date.today.beginning_of_month - 10.month }
    let(:plan_year_end) {  (plan_year_start + 8.month).end_of_month }

    it "should return true if terminated plan year present" do
      expect(subject.should_send_retroactive_term_or_cancel?(carrier)).to be_truthy
    end

    it "should return false " do
      expect(subject.has_current_or_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false" do
      expect(subject.drop_and_has_future_plan_year?(carrier)).to be_falsey
    end

    it "should return false" do
      expect(subject.renewal_and_no_future_plan_year?(carrier)).to be_falsey
    end
  end
end

describe BenefitSponsors::EmployerEvents::Renderer, "given an xml, from which it selects carrier plan years", :dbclean => :after_each do
  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"
  include_context "setup renewal application"

  let(:event_time) { double }
  let(:employer_profile) { FactoryGirl.create(:benefit_sponsors_benefit_sponsorship, :with_benefit_market, :with_organization_cca_profile, :with_renewal_benefit_application)}
  let(:employer) {employer_profile.organization}
  let(:employer_id) {employer.hbx_id}
  let(:old_plan_year) { employer_profile.benefit_applications.last }
  let(:old_plan_year_start_date) {old_plan_year.effective_period.min.strftime("%Y%m%d")}
  let(:old_plan_year_end_date) { old_plan_year.effective_period.max.strftime("%Y%m%d")}
  let(:plan_year) {employer_profile.benefit_applications.first }
  let(:start_date) {plan_year.effective_period.min.strftime("%Y%m%d")}
  let(:end_date) { plan_year.effective_period.max.strftime("%Y%m%d")}
  let(:carrier) {plan_year.benefit_packages.first.health_sponsored_benefit.reference_product.issuer_profile}
  let(:old_carrier) {old_plan_year.benefit_packages.first.health_sponsored_benefit.reference_product.issuer_profile}
  let!(:plan_years) { [plan_year, old_plan_year]}
  let(:hbx_carrier_id) { "20001"}
  let(:renewal_successful_event) { BenefitSponsors::EmployerEvents::EventNames::RENEWAL_SUCCESSFUL_EVENT }
  let(:renewal_carrier_change_event) { BenefitSponsors::EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT }
  let(:first_time_employer_event_name) { BenefitSponsors::EmployerEvents::EventNames::FIRST_TIME_EMPLOYER_EVENT_NAME }

  let(:source_document) do
    <<-XMLCODE
    <organization xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://openhbx.org/api/terms/1.0" xsi:type="EmployerOrganizationType">
      <id>
        <id>#{employer_id}</id>
      </id>
      <name>#{employer.legal_name}</name>
      <fein>#{employer.fein}</fein>
      <office_locations>
        <office_location>
          <id>
            <id>5b46cfafaea91a66a346fd4c</id>
          </id>
          <primary>true</primary>
          <address>
           <type>urn:openhbx:terms:v1:address_type#work</type>
            <address_line_1>245 E OLD STURBRIDGE RD</address_line_1>
            <location_city_name>BRIMFIELD</location_city_name>
            <location_county_name>Hampden</location_county_name>
            <location_state>urn:openhbx:terms:v1:us_state#massachusetts</location_state>
            <location_state_code>MA</location_state_code>
            <postal_code>01010</postal_code>
            <location_country_name/>
            <address_full_text>245 E OLD STURBRIDGE RD  BRIMFIELD, MA 01010</address_full_text>
          </address>
          <phone>
            <type>urn:openhbx:terms:v1:phone_type#work</type>
            <area_code>413</area_code>
            <phone_number>2453100</phone_number>
            <full_phone_number>4132453100</full_phone_number>
            <is_preferred>false</is_preferred>
          </phone>
        </office_location>
      </office_locations>
      <is_active>true</is_active>
      <employer_profile>
        <business_entity_kind>urn:openhbx:terms:v1:employers#s_corporation</business_entity_kind>
        <sic_code>4725</sic_code>
        <plan_years>
          <plan_year>
            <plan_year_start>#{start_date}</plan_year_start>
            <plan_year_end>#{end_date}</plan_year_end>
            <fte_count>2</fte_count>
            <pte_count>0</pte_count>
            <open_enrollment_start>20180201</open_enrollment_start>
            <open_enrollment_end>20180320</open_enrollment_end>
            <benefit_groups>
              <benefit_group>
                  <id>
                    <id>5b46d3ddaea91a38fa64aebf</id>
                  </id>
                  <name>Standard</name>
                  <group_size>1</group_size>
                  <participation_rate>0.01</participation_rate>
                  <rating_area>R-MA001</rating_area>
                  <elected_plans>
                    <elected_plan>
                      <id>
                        <id>59763MA0030011-01</id>
                      </id>
                      <name>Direct Gold 1000</name>
                      <active_year>2018</active_year>
                      <is_dental_only>false</is_dental_only>
                      <carrier>
                        <id>
                          <id>20001</id>
                        </id>
                        <name>Tufts Health Direct</name>
                        <is_active>true</is_active>
                      </carrier>
                      <metal_level>urn:openhbx:terms:v1:plan_metal_level#gold</metal_level>
                      <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
                      <ehb_percent>99.5</ehb_percent>
                    </elected_plan>
                  </elected_plans>
              </benefit_group>
            </benefit_groups>
            <created_at>2018-07-12T04:06:53Z</created_at>
            <modified_at>2018-07-12T04:06:53Z</modified_at>
          </plan_year>
          <plan_year>
            <plan_year_start>#{old_plan_year_start_date}</plan_year_start>
            <plan_year_end>#{old_plan_year_end_date}</plan_year_end>
            <fte_count>2</fte_count>
            <pte_count>0</pte_count>
            <open_enrollment_start>20180201</open_enrollment_start>
            <open_enrollment_end>20180320</open_enrollment_end>
            <benefit_groups>
              <benefit_group>
                <id>
                  <id>5b46d3ddaea91a38fa64aebf</id>
                </id>
                <name>Standard</name>
                <group_size>1</group_size>
                <participation_rate>0.01</participation_rate>
                <rating_area>R-MA001</rating_area>
                <elected_plans>
                  <elected_plan>
                    <id>
                      <id>59763MA0030011-01</id>
                    </id>
                    <name>Direct Gold 1000</name>
                    <active_year>2018</active_year>
                    <is_dental_only>false</is_dental_only>
                      <carrier>
                        <id>
                          <id>CARRIER HBX ID</id>
                        </id>
                        <name>Tufts Health Direct</name>
                        <is_active>true</is_active>
                      </carrier>
                    <metal_level>urn:openhbx:terms:v1:plan_metal_level#gold</metal_level>
                    <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
                    <ehb_percent>99.5</ehb_percent>
                    </elected_plan>
                </elected_plans>
              </benefit_group>
            </benefit_groups>
            <created_at>2018-07-12T04:06:53Z</created_at>
            <modified_at>2018-07-12T04:06:53Z</modified_at>
          </plan_year>
        </plan_years>
      </employer_profile>
      <created_at>2018-07-12T03:49:03Z</created_at>
      <modified_at>2019-02-25T22:09:12Z</modified_at>
    </organization>
    XMLCODE
  end

  let(:employer_event) do
    instance_double(BenefitSponsors::Services::EmployerEvent,
                    { event_time: event_time,
                      event_name: renewal_successful_event,
                      resource_body: source_document,
                      employer_profile_id: employer_profile.hbx_id})
  end
  let(:renewal_carrier_change_employer_event) do
    instance_double(BenefitSponsors::Services::EmployerEvent,
                    { event_time: event_time,
                      event_name: renewal_carrier_change_event,
                      resource_body: source_document,
                      employer_profile_id: employer_profile.hbx_id})
  end
  let!(:doc)  {Nokogiri::XML(employer_event.resource_body)}

  describe "with plan years for the specified carrier", :dbclean => :after_each do

    subject do
      BenefitSponsors::EmployerEvents::Renderer.new(employer_event)
    end

    it "finds updates the event if there is a previous plan year" do
      allow(carrier).to receive(:hbx_carrier_id).and_return(hbx_carrier_id)

      expect(subject.update_event_name(carrier, employer_event)).to eq renewal_successful_event
      expect(subject.update_event_name(carrier, renewal_carrier_change_employer_event)).to eq renewal_carrier_change_event
    end
  end

  describe BenefitSponsors::EmployerEvents::Renderer, "given an xml, from which it selects carrier plan years", :dbclean => :after_each do

    let(:first_time_employer_source_document) do
      <<-XMLCODE
      <organization xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://openhbx.org/api/terms/1.0" xsi:type="EmployerOrganizationType">
        <id>
          <id>#{employer_id}</id>
        </id>
        <name>#{employer.legal_name}</name>
        <fein>#{employer.fein}</fein>
        <office_locations>
          <office_location>
            <id>
              <id>5b46cfafaea91a66a346fd4c</id>
            </id>
            <primary>true</primary>
            <address>
             <type>urn:openhbx:terms:v1:address_type#work</type>
              <address_line_1>245 E OLD STURBRIDGE RD</address_line_1>
              <location_city_name>BRIMFIELD</location_city_name>
              <location_county_name>Hampden</location_county_name>
              <location_state>urn:openhbx:terms:v1:us_state#massachusetts</location_state>
              <location_state_code>MA</location_state_code>
              <postal_code>01010</postal_code>
              <location_country_name/>
              <address_full_text>245 E OLD STURBRIDGE RD  BRIMFIELD, MA 01010</address_full_text>
            </address>
            <phone>
              <type>urn:openhbx:terms:v1:phone_type#work</type>
              <area_code>413</area_code>
              <phone_number>2453100</phone_number>
              <full_phone_number>4132453100</full_phone_number>
              <is_preferred>false</is_preferred>
            </phone>
          </office_location>
        </office_locations>
        <is_active>true</is_active>
        <employer_profile>
          <business_entity_kind>urn:openhbx:terms:v1:employers#s_corporation</business_entity_kind>
          <sic_code>4725</sic_code>
          <plan_years>
            <plan_year>
              <plan_year_start>#{old_plan_year_start_date}</plan_year_start>
              <plan_year_end>#{old_plan_year_end_date}</plan_year_end>
              <fte_count>2</fte_count>
              <pte_count>0</pte_count>
              <open_enrollment_start>20180201</open_enrollment_start>
              <open_enrollment_end>20180320</open_enrollment_end>
              <benefit_groups>
                <benefit_group>
                    <id>
                      <id>5b46d3ddaea91a38fa64aebf</id>
                    </id>
                    <name>Standard</name>
                    <group_size>1</group_size>
                    <participation_rate>0.01</participation_rate>
                    <rating_area>R-MA001</rating_area>
                    <elected_plans>
                      <elected_plan>
                        <id>
                          <id>59763MA0030011-01</id>
                        </id>
                        <name>Direct Gold 1000</name>
                        <active_year>2018</active_year>
                        <is_dental_only>false</is_dental_only>
                        <carrier>
                          <id>
                            <id>20001</id>
                          </id>
                          <name>Tufts Health Direct</name>
                          <is_active>true</is_active>
                        </carrier>
                        <metal_level>urn:openhbx:terms:v1:plan_metal_level#gold</metal_level>
                        <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
                        <ehb_percent>99.5</ehb_percent>
                      </elected_plan>
                    </elected_plans>
                </benefit_group>
              </benefit_groups>
              <created_at>2018-07-12T04:06:53Z</created_at>
              <modified_at>2018-07-12T04:06:53Z</modified_at>
            </plan_year>
          </plan_years>
        </employer_profile>
        <created_at>2018-07-12T03:49:03Z</created_at>
        <modified_at>2019-02-25T22:09:12Z</modified_at>
      </organization>
      XMLCODE
    end
    let(:first_time_employer_event) do
      instance_double(BenefitSponsors::Services::EmployerEvent,
                      { event_time: event_time,
                        event_name: first_time_employer_event_name,
                        resource_body: first_time_employer_source_document,
                        employer_profile_id: employer_profile.hbx_id})
    end

    subject do
      BenefitSponsors::EmployerEvents::Renderer.new(first_time_employer_event)
    end

    describe "with plan years for the specified carrier" do
      it "finds updates the event if there is a previous plan year" do
        allow(carrier).to receive(:hbx_carrier_id).and_return(hbx_carrier_id)

        expect(subject.update_event_name(carrier, first_time_employer_event)).to eq first_time_employer_event_name
      end
    end
  end
end

describe BenefitSponsors::EmployerEvents::Renderer, "given:
  - an xml, from which it selects carrier plan years
  - a previous plan year in the database", :dbclean => :after_each do

  include_context "setup benefit market with market catalogs and product packages"
  include_context "setup initial benefit application"
  include_context "setup renewal application"

  let(:event_time) { double }
  let(:employer_profile_hbx_id) {benefit_sponsorship.hbx_id}
  let(:employer) {benefit_sponsorship.organization}
  let(:employer_id) {employer.hbx_id}
  let(:old_plan_year) { benefit_sponsorship.benefit_applications.last }
  let(:old_plan_year_start_date) {old_plan_year.effective_period.min.strftime("%Y%m%d")}
  let(:old_plan_year_end_date) { old_plan_year.effective_period.max.strftime("%Y%m%d")}
  let(:plan_year) {benefit_sponsorship.benefit_applications.first }
  let(:start_date) {plan_year.effective_period.min.strftime("%Y%m%d")}
  let(:end_date) { plan_year.effective_period.max.strftime("%Y%m%d")}
  let(:carrier) {plan_year.benefit_packages.first.health_sponsored_benefit.reference_product.issuer_profile}
  let(:old_carrier) {old_plan_year.benefit_packages.first.health_sponsored_benefit.reference_product.issuer_profile}
  let!(:plan_years) { [plan_year, old_plan_year]}
  let(:hbx_carrier_id) { 20_004 }
  let(:previous_plan_year_carrier_id) {20_004}
  let(:renewal_successful_event) { BenefitSponsors::EmployerEvents::EventNames::RENEWAL_SUCCESSFUL_EVENT }
  let(:renewal_carrier_change_event) { BenefitSponsors::EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT }
  let(:first_time_employer_event_name) { BenefitSponsors::EmployerEvents::EventNames::FIRST_TIME_EMPLOYER_EVENT_NAME }
  let(:source_document) do
    <<-XMLCODE
    <organization xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://openhbx.org/api/terms/1.0" xsi:type="EmployerOrganizationType">
      <id>
        <id>#{employer.hbx_id}</id>
      </id>
     <name>#{employer.legal_name}</name>
      <fein>#{employer.fein}</fein>
      <office_locations>
        <office_location>
          <id>
            <id>5b46cfafaea91a66a346fd4c</id>
          </id>
          <primary>true</primary>
          <address>
           <type>urn:openhbx:terms:v1:address_type#work</type>
            <address_line_1>245 E OLD STURBRIDGE RD</address_line_1>
            <location_city_name>BRIMFIELD</location_city_name>
            <location_county_name>Hampden</location_county_name>
            <location_state>urn:openhbx:terms:v1:us_state#massachusetts</location_state>
            <location_state_code>MA</location_state_code>
            <postal_code>01010</postal_code>
            <location_country_name/>
            <address_full_text>245 E OLD STURBRIDGE RD  BRIMFIELD, MA 01010</address_full_text>
          </address>
          <phone>
            <type>urn:openhbx:terms:v1:phone_type#work</type>
            <area_code>413</area_code>
            <phone_number>2453100</phone_number>
            <full_phone_number>4132453100</full_phone_number>
            <is_preferred>false</is_preferred>
          </phone>
        </office_location>
      </office_locations>
      <is_active>true</is_active>
      <employer_profile>
        <business_entity_kind>urn:openhbx:terms:v1:employers#s_corporation</business_entity_kind>
        <sic_code>4725</sic_code>
        <plan_years>
          <plan_year>
            <plan_year_start>#{start_date}</plan_year_start>
            <plan_year_end>#{end_date}</plan_year_end>
            <fte_count>2</fte_count>
            <pte_count>0</pte_count>
            <open_enrollment_start>20180201</open_enrollment_start>
            <open_enrollment_end>20180320</open_enrollment_end>
            <benefit_groups>
              <benefit_group>
                  <id>
                    <id>5b46d3ddaea91a38fa64aebf</id>
                  </id>
                  <name>Standard</name>
                  <group_size>1</group_size>
                  <participation_rate>0.01</participation_rate>
                  <rating_area>R-MA001</rating_area>
                  <elected_plans>
                    <elected_plan>
                      <id>
                        <id>59763MA0030011-01</id>
                      </id>
                      <name>Direct Gold 1000</name>
                      <active_year>2018</active_year>
                      <is_dental_only>false</is_dental_only>
                      <carrier>
                        <id>
                          <id>#{hbx_carrier_id}</id>
                        </id>
                        <name>Tufts Health Direct</name>
                        <is_active>true</is_active>
                      </carrier>
                      <metal_level>urn:openhbx:terms:v1:plan_metal_level#gold</metal_level>
                      <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
                      <ehb_percent>99.5</ehb_percent>
                    </elected_plan>
                  </elected_plans>
              </benefit_group>
            </benefit_groups>
            <created_at>2018-07-12T04:06:53Z</created_at>
            <modified_at>2018-07-12T04:06:53Z</modified_at>
          </plan_year>
          <plan_year>
            <plan_year_start>#{old_plan_year_start_date}</plan_year_start>
            <plan_year_end>#{old_plan_year_end_date}</plan_year_end>
            <fte_count>2</fte_count>
            <pte_count>0</pte_count>
            <open_enrollment_start>20180201</open_enrollment_start>
            <open_enrollment_end>20180320</open_enrollment_end>
            <benefit_groups>
              <benefit_group>
                <id>
                  <id>5b46d3ddaea91a38fa64aebf</id>
                </id>
                <name>Standard</name>
                <group_size>1</group_size>
                <participation_rate>0.01</participation_rate>
                <rating_area>R-MA001</rating_area>
                <elected_plans>
                  <elected_plan>
                    <id>
                      <id>59763MA0030011-01</id>
                    </id>
                    <name>Direct Gold 1000</name>
                    <active_year>2018</active_year>
                    <is_dental_only>false</is_dental_only>
                      <carrier>
                        <id>
                          <id>#{previous_plan_year_carrier_id}</id>
                        </id>
                        <name>Tufts Health Direct</name>
                        <is_active>true</is_active>
                      </carrier>
                    <metal_level>urn:openhbx:terms:v1:plan_metal_level#gold</metal_level>
                    <coverage_type>urn:openhbx:terms:v1:qhp_benefit_coverage#health</coverage_type>
                    <ehb_percent>99.5</ehb_percent>
                    </elected_plan>
                </elected_plans>
              </benefit_group>
            </benefit_groups>
            <created_at>2018-07-12T04:06:53Z</created_at>
            <modified_at>2018-07-12T04:06:53Z</modified_at>
          </plan_year>
        </plan_years>
      </employer_profile>
      <created_at>2018-07-12T03:49:03Z</created_at>
      <modified_at>2019-02-25T22:09:12Z</modified_at>
    </organization>
    XMLCODE
  end

  let(:employer_event) do
    instance_double(BenefitSponsors::Services::EmployerEvent,
                    { event_time: event_time,
                      event_name: renewal_successful_event,
                      resource_body: source_document,
                      employer_profile_id: employer_profile_hbx_id})
  end
  let(:first_time_employer_event) do
    instance_double(BenefitSponsors::Services::EmployerEvent,
                    { event_time: event_time,
                      event_name: first_time_employer_event_name,
                      resource_body: source_document,
                      employer_profile_id: employer_profile_hbx_id})
  end

  let!(:doc)  {Nokogiri::XML(employer_event.resource_body)}

  subject do
    BenefitSponsors::EmployerEvents::Renderer.new(employer_event)
  end

  before :each do
    allow(carrier).to receive(:hbx_carrier_id).and_return(hbx_carrier_id)
    allow(old_carrier).to receive(:hbx_carrier_id).and_return(hbx_carrier_id)
    benefit_sponsorship.benefit_applications[1].delete
  end

  context "when the past plan year is not for the same carrier as the current plan year" do
    let(:previous_plan_year_carrier_id) { "SOME OTHER CARRIER ID" }

    it "updates the renewal event to be an initial event" do
      allow(old_carrier).to receive(:hbx_carrier_id).and_return(previous_plan_year_carrier_id)

      expect(subject.update_event_name(carrier, employer_event)).to eq BenefitSponsors::EmployerEvents::EventNames::FIRST_TIME_EMPLOYER_EVENT_NAME
    end

    it "keeps the initial event as an initial event" do
      allow(old_carrier).to receive(:hbx_carrier_id).and_return(previous_plan_year_carrier_id)

      expect(subject.update_event_name(old_carrier, first_time_employer_event)).to eq BenefitSponsors::EmployerEvents::EventNames::FIRST_TIME_EMPLOYER_EVENT_NAME
    end
  end

  context "when the past plan year is for the same carrier as the current plan year" do

    it "keeps the renewal event to be a renewal event" do
      bs = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.first
      bs.benefit_applications.last.benefit_packages.map(&:sponsored_benefits).flatten.map(&:reference_product).flatten.map(&:issuer_profile).first.update_attributes(hbx_carrier_id: 20_004)
      bs.benefit_applications.first.benefit_packages.map(&:sponsored_benefits).flatten.map(&:reference_product).flatten.map(&:issuer_profile).first.update_attributes(hbx_carrier_id: 20_004)
      expect(subject.update_event_name(carrier, employer_event)).to eq renewal_successful_event
    end

    it "changes the initial event to a renewal event" do
      bs = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.first
      bs.benefit_applications.last.benefit_packages.map(&:sponsored_benefits).flatten.map(&:reference_product).flatten.map(&:issuer_profile).first.update_attributes(hbx_carrier_id: 20_004)
      bs.benefit_applications.first.benefit_packages.map(&:sponsored_benefits).flatten.map(&:reference_product).flatten.map(&:issuer_profile).first.update_attributes(hbx_carrier_id: 20_004)
      expect(subject.update_event_name(old_carrier, first_time_employer_event)).to eq renewal_successful_event
    end
  end

  context "when the past plan year is for the same carrier as the current plan year BUT the previous plan year is short" do
    let(:previous_start_date) {old_plan_year.effective_period.min}
    let(:previous_end_date) { old_plan_year.effective_period.max - 4.months}
    let(:old_plan_year_end_date) { previous_end_date.strftime("%Y%m%d")}

    it "updates the renewal event to be an initial event" do
      old_plan_year.update_attributes(:effective_period => previous_start_date..previous_end_date)
      expect(subject.update_event_name(carrier, employer_event)).to eq first_time_employer_event_name
    end

    it "keeps the initial event as an initial event" do
      old_plan_year.update_attributes(:effective_period => previous_start_date..previous_end_date)
      expect(subject.update_event_name(old_carrier, first_time_employer_event)).to eq first_time_employer_event_name
    end
  end
end
