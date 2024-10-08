# frozen_string_literal: true

require "rails_helper"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_market.rb"
require "#{BenefitSponsors::Engine.root}/spec/shared_contexts/benefit_application.rb"

class EventsHelperSlug
  include EventsHelper
end

describe EventsHelper, "given an address_kind", dbclean: :after_each do

  subject { EventsHelperSlug.new }

  describe "when the address kind is 'primary'" do
    it "should return address kind as 'work'" do
      expect(subject.office_location_address_kind("primary")).to eq "work"
    end
  end

  describe "when the address kind is 'branch'" do
    it "should return address kind as 'work'" do
      expect(subject.office_location_address_kind("branch")).to eq "work"
    end
  end

  describe "when the address kind is anything else" do
    it "should return address kind as the same" do
      expect(subject.office_location_address_kind("slkdjfkld")).to eq "slkdjfkld"
    end
  end

  describe "employer_plan_years" do

    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup renewal application"

    context "initial employer" do
      context "day is after open enrollment of this month" do
        let(:current_date_of_record) { TimeKeeper.date_of_record.at_beginning_of_month + 21.days }

        before do
          predecessor_application.update_attributes({:aasm_state => "enrollment_eligible"})
          allow(TimeKeeper).to receive(:date_of_record).and_return(current_date_of_record)
        end

        it "should return active plan year" do
          expect(subject.employer_plan_years(abc_profile, nil)).to eq [predecessor_application]
        end
      end

      context "day is before open enrollment of this month" do
        let(:current_date_of_record) { TimeKeeper.date_of_record.at_beginning_of_month }

        before do
          predecessor_application.update_attributes({:aasm_state => "draft"})
          allow(TimeKeeper).to receive(:date_of_record).and_return(current_date_of_record)
        end

        it "should not return plan years" do
          expect(subject.employer_plan_years(abc_profile, nil)).to eq []
        end
      end
    end

    context "renewal employer" do

      context "day is after open enrollment this month" do

        before do
          predecessor_application.update_attributes({:aasm_state => "active"})
          renewal_application.update_attributes({:aasm_state => "enrollment_eligible"})
          allow(TimeKeeper).to receive(:date_of_record).and_return(TimeKeeper.date_of_record.at_beginning_of_month + 21.days)
        end

        it "should return active and renewal plan year" do
          expect(subject.employer_plan_years(abc_profile, renewal_application.id.to_s)).to eq [renewal_application,predecessor_application]
        end
      end

      context "day is before open enrollment this month" do

        before do
          predecessor_application.update_attributes({:aasm_state => "active"})
          renewal_application.update_attributes({:aasm_state => "draft"})
          allow(TimeKeeper).to receive(:date_of_record).and_return(TimeKeeper.date_of_record.at_beginning_of_month)
        end

        it "should return active plan year" do
          expect(subject.employer_plan_years(abc_profile, nil)).to eq [predecessor_application]
        end
      end
    end

    context "conversion employer with no external plan year" do

      before do
        allow(TimeKeeper).to receive(:date_of_record).and_return(TimeKeeper.date_of_record.at_beginning_of_month + 21.days)
        predecessor_application.update_attributes({:aasm_state => "enrollment_eligible"})
      end

      context "day is after open enrollment this month" do

        it "should return active plan year" do
          abc_profile.benefit_applications.first.benefit_sponsorship.source_kind = "conversion"
          abc_profile.save
          expect(subject.employer_plan_years(abc_profile, nil)).to eq [predecessor_application]
        end
      end

      context "day is before open enrollment this month" do

        before do
          allow(TimeKeeper).to receive(:date_of_record).and_return(TimeKeeper.date_of_record.at_beginning_of_month)
          predecessor_application.update_attributes({:aasm_state => "draft"})
        end

        it "should not return plan years" do
          abc_profile.benefit_applications.first.benefit_sponsorship.source_kind = "conversion"
          abc_profile.save
          expect(subject.employer_plan_years(abc_profile, nil)).to eq []
        end
      end
    end

    context "new conversion employer" do

      context "day is after open enrollment this month" do
        before do
          allow(TimeKeeper).to receive(:date_of_record).and_return(TimeKeeper.date_of_record.at_beginning_of_month + 21.days)
          predecessor_application.update_attributes({:aasm_state => "active"})
          renewal_application.update_attributes({:aasm_state => "enrollment_eligible"})
        end

        it "should return active and renewal plan year" do
          abc_profile.benefit_applications.first.benefit_sponsorship.source_kind = "conversion"
          abc_profile.save
          expect(subject.employer_plan_years(abc_profile, renewal_application.id.to_s)).to eq [renewal_application,predecessor_application]
        end
      end

      context "day is before open enrollment this month" do

        before do
          allow(TimeKeeper).to receive(:date_of_record).and_return(TimeKeeper.date_of_record.at_beginning_of_month)
          predecessor_application.update_attributes({:aasm_state => "draft"})
        end

        it "should not return plan years" do
          abc_profile.benefit_applications.first.benefit_sponsorship.source_kind = "conversion"
          abc_profile.save
          expect(subject.employer_plan_years(abc_profile, nil)).to eq []
        end
      end
    end

    context "conversion employer renewing" do

      context "day is after open enrollment this month" do

        before do
          allow(TimeKeeper).to receive(:date_of_record).and_return(TimeKeeper.date_of_record.at_beginning_of_month + 21.days)
          predecessor_application.update_attributes({:aasm_state => "active"})
          renewal_application.update_attributes({:aasm_state => "enrollment_eligible"})
        end

        it "should return active and renewal plan year" do
          abc_profile.benefit_applications.first.benefit_sponsorship.source_kind = "conversion"
          abc_profile.save
          expect(subject.employer_plan_years(abc_profile, renewal_application.id.to_s)).to eq [renewal_application,predecessor_application]
        end
      end

      context "day is before open enrollment this month" do

        before do
          allow(TimeKeeper).to receive(:date_of_record).and_return(TimeKeeper.date_of_record.at_beginning_of_month)
          predecessor_application.update_attributes({:aasm_state => "enrollment_eligible"})
        end

        it "should return active_plan_year" do
          abc_profile.benefit_applications.first.benefit_sponsorship.source_kind = "conversion"
          abc_profile.save
          expect(subject.employer_plan_years(abc_profile, nil)).to eq [predecessor_application]
        end
      end
    end
  end

  describe "is_office_location_address_valid?" do

    let(:phone) { FactoryBot.build(:phone) }
    let(:address)  { Address.new(kind: "primary", address_1: "609 H St", city: "Washington", state: "DC", zip: "20002") }
    let(:address1)  { Address.new(kind: "branch", address_1: "609 H St", city: "Washington", state: "DC", zip: "20002") }
    let(:office_location) { OfficeLocation.new(is_primary: true, address: address, phone: phone)}
    let(:office_location1) { OfficeLocation.new(is_primary: true, address: address1, phone: phone)}

    context "office location with valid address kind" do

      it "should return true" do
        expect(subject.is_office_location_address_valid?(office_location)).to eq true
      end
    end

    context "office location with invalid address kind" do

      it "should return false " do
        expect(subject.is_office_location_address_valid?(office_location1)).to eq false
      end
    end
  end

  describe "is_office_location_phone_valid?" do

    let(:phone) { FactoryBot.build(:phone, kind: 'home') }
    let(:phone1) { FactoryBot.build(:phone, kind: 'phone main main') }
    let(:address)  { Address.new(kind: "primary", address_1: "609 H St", city: "Washington", state: "DC", zip: "20002") }
    let(:address1)  { Address.new(kind: "branch", address_1: "609 H St", city: "Washington", state: "DC", zip: "20002") }
    let(:office_location) { OfficeLocation.new(is_primary: true, address: address, phone: phone)}
    let(:office_location1) { OfficeLocation.new(is_primary: true, address: address1, phone: phone1)}

    context "office location with valid phone kind" do

      it "should return true" do
        expect(subject.is_office_location_phone_valid?(office_location)).to eq true
      end
    end

    context "office location with invalid phone kind" do

      it "should return false " do
        expect(subject.is_office_location_phone_valid?(office_location1)).to eq false
      end
    end
  end

end

describe EventsHelper, "transforming a qualifying event kind for external xml", dbclean: :after_each do

  RESULT_PAIR = {
    "relocate" => "location_change",
    "eligibility_change_immigration_status" => "citizen_status_change",
    "lost_hardship_exemption" => "eligibility_change_assistance",
    "eligibility_change_income" => "eligibility_change_assistance",
    "court_order" => "medical_coverage_order",
    "domestic_partnership" => "entering_domestic_partnership",
    "new_eligibility_member" => "drop_family_member_due_to_new_eligibility",
    "new_eligibility_family" => "drop_family_member_due_to_new_eligibility",
    "employer_sponsored_coverage_termination" => "eligibility_change_employer_ineligible",
    "divorce" => "divorce",
    "unknown_sep" => "exceptional_circumstances"
  }.freeze

  subject { EventsHelperSlug.new }

  RESULT_PAIR.each_pair do |k,v|
    it "maps \"#{k}\" to \"#{v}\"" do
      eligibility_event = instance_double(HbxEnrollment, :eligibility_event_kind => k)
      expect(subject.xml_eligibility_event_uri(eligibility_event)).to eq "urn:dc0:terms:v1:qualifying_life_event##{v}"
    end
  end

end

describe EventsHelper, "selecting plan years to be exported", dbclean: :after_each do
  subject { EventsHelperSlug.new }

  describe "plan_years_for_manual_export" do

    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup renewal application"

    context "draft plan year" do
      before do
        predecessor_application.update_attributes({:aasm_state => "draft"})
      end

      it "should return []" do
        expect(subject.plan_years_for_manual_export(abc_profile)).to eq []
      end
    end

    context "enrolled plan year" do
      before do
        predecessor_application.update_attributes({:aasm_state => "enrollment_eligible"})
      end

      it "should return the plan year" do
        expect(subject.plan_years_for_manual_export(abc_profile)).to eq [predecessor_application]
      end
    end

    context "terminated plan year with future date of termination" do
      before do
        predecessor_application.update_attributes(:aasm_state => "terminated")
        predecessor_application.benefit_application_items.create({
                                                                   effective_period: predecessor_application.start_on..TimeKeeper.date_of_record + 1.month,
                                                                   state: :terminated,
                                                                   sequence_id: 1
                                                                 })
      end

      it "should return the plan year" do
        expect(subject.plan_years_for_manual_export(abc_profile)).to eq [predecessor_application]
      end
    end

    context "expired plan year" do
      before do
        predecessor_application.update_attributes({:aasm_state => "expired"})
      end

      it "should return the expired plan year" do
        expect(subject.plan_years_for_manual_export(abc_profile)).to eq [predecessor_application]
      end
    end

    context "active and canceled plan year" do
      before do
        renewal_application.update_attributes({:aasm_state => "renewing_canceled"})
      end

      it "should not return the plan year" do
        expect(subject.plan_years_for_manual_export(abc_profile)).to eq [predecessor_application]
      end
    end
  end
end

describe EventsHelper, "employer_plan_years", dbclean: :after_each do
  subject { EventsHelperSlug.new }

  describe "should export valid plan years" do


    include_context "setup benefit market with market catalogs and product packages"
    include_context "setup renewal application"


    context "employer with active and renewing enrolled plan year" do

      before do
        predecessor_application.update_attributes({:aasm_state => "active"})
        renewal_application.update_attributes({:aasm_state => "enrollment_eligible"})
      end

      it "should return active and renewing plan year" do
        expect(subject.employer_plan_years(abc_profile, nil)).to eq [renewal_application,predecessor_application]
      end
    end

    context "employer with active and canceled plan year" do

      before do
        predecessor_application.update_attributes({:aasm_state => "active"})
        renewal_application.update_attributes({:aasm_state => "canceled"})  # renewal application cancelled
      end

      it "should return active plan year when canceled plan id not passed to export" do
        expect(subject.employer_plan_years(abc_profile, nil)).to eq [predecessor_application]
      end

      context "when canceled plan year id passed to export" do
        it "should return active & canceled plan year" do
          expect(subject.employer_plan_years(abc_profile, renewal_application.id.to_s)).to eq [renewal_application, predecessor_application]
        end
      end
    end

    context "employer with terminated plan year" do
      before do
        predecessor_application.update_attributes({:aasm_state => "terminated"}) # active application terminated
        renewal_application.update_attributes({:aasm_state => "canceled"})
      end

      it "should return terminated plan year" do
        expect(subject.employer_plan_years(abc_profile, nil)).to eq [predecessor_application]
      end
    end

    context "employer with terminated pending plan year " do
      before do
        predecessor_application.update_attributes({:aasm_state => "termination_pending"})
        renewal_application.update_attributes({:aasm_state => "canceled"})
      end

      it "should return the terminated pending plan year" do
        expect(subject.employer_plan_years(abc_profile, nil)).to eq [predecessor_application]
      end
    end
  end
end