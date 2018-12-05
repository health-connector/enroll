require 'rails_helper'
require 'rake'
require 'csv'

describe 'Export Employer report', :dbclean => :after_each do
  let(:time_extract) {TimeKeeper.datetime_of_record.try(:strftime, '%Y_%m_%d_%H_%M_%S')}
  let(:task_name_MA) {"EMPLOYEREXPORT"}

  before do
    load File.expand_path("#{Rails.root}/lib/tasks/export_employers.rake", __FILE__)
    Rake::Task.define_task(:environment)
    @file = "#{Rails.root}/public/CCA_#{ENV["RAILS_ENV"]}_#{task_name_MA}_#{time_extract}.csv"
  end

  it 'should generate csv report with given headers' do
    Rake::Task["export:employers"].invoke
    result =  [%w(employer.legal_name employer.dba employer.fein employer.hbx_id employer.entity_kind 
                    employer.sic_code employer_profile.profile_source employer.referred_by employer.referred_reason 
                    employer.status ga_fein ga_agency_name ga_start_on office_location.is_primary office_location.address.address_1 
                    office_location.address.address_2 office_location.address.city office_location.address.state office_location.address.zip
                    office_location.address.county mailing_location.address_1 mailing_location.address_2 mailing_location.city
                    mailing_location.state mailing_location.zip mailing_location.county office_location.phone.full_phone_number
                    staff.name staff.phone staff.email employee offered spouce offered domestic_partner offered child_under_26
                    offered child_26_and_over offered benefit_group.title benefit_group.plan_option_kind export_group_size_count
                    export_participation_rate rate_basis_type rating_area_code estimated_composite_premium.Employee_Only
                    estimated_composite_premium.Employee_Spouse estimated_composite_premium.Employee_Children estimated_composite_premium.Family 
                    final_composite_premium.Employee_Only final_composite_premium.Employee_Spouse final_composite_premium.Employee_Children 
                    final_composite_premium.Family composite_premium_percentage.Employee composite_premium_percentage.Spouse 
                    composite_premium_percentage.Domestic_Partner composite_premium_percentage.Child_Under_26 composite_premium_percentage.Family 
                    benefit_group.carrier_for_elected_plan benefit_group.metal_level_for_elected_plan benefit_group.single_plan_type? 
                    benefit_group.reference_plan.name benefit_group.effective_on_kind benefit_group.effective_on_offset plan_year.start_on 
                    plan_year.end_on plan_year.open_enrollment_start_on plan_year.open_enrollment_end_on Renewal_plan_year_rates plan_year.fte_count 
                    plan_year.pte_count plan_year.msp_count plan_year.status plan_year.publish_date broker_agency_account.corporate_npn 
                    broker_agency_account.legal_name broker.name broker.npn broker.assigned_on)]

    data = CSV.read "#{Rails.root}/public/CCA_#{ENV["RAILS_ENV"]}_#{task_name_MA}_#{time_extract}.csv"
    expect(data).to eq result
  end

  it "creates csv file" do
    file_context = CSV.read(@file)
    expect(file_context.size).to be > 0
  end

  it 'should generate user csv report in hbx_report' do
    Rake::Task["export:employers"].invoke
    expect(File.exists?("#{Rails.root}/public/CCA_#{ENV["RAILS_ENV"]}_#{task_name_MA}_#{time_extract}.csv")).to be true
  end

  after(:all) do
    Dir.glob("#{Rails.root}/public/CCA_#{ENV["RAILS_ENV"]}_*.csv").each do |file|
      File.delete(file)
    end
  end
end
