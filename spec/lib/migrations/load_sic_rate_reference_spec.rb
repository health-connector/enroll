require 'rails_helper'

RSpec.shared_examples "a sic area rate reference" do |attributes|
  attributes.each do |attribute, value|
    it "should return #{value} from ##{attribute}" do
      expect(subject.send(attribute)).to eq(value)
    end
  end
 end
RSpec.describe 'Sic Rate Reference', :type => :task do
 
  context "load_sic_rate_reference:update_sic_code" do
 
    before :all do
      Rake.application.rake_require "tasks/migrations/load_sic_rate_reference"
      Rake::Task.define_task(:environment)
    end
 
    before :context do
      invoke_task
    end
 
    imported_sic_rate_references = SicRateReference.all
    context "it creates SicRateReference elements correctly" do
      subject { imported_sic_rate_references.first }
      it_should_behave_like "a sic area rate reference", {
                                                  sic: "0111",
                                                  hios_id: "82569",
                                                  cost_ratio: 1.000,
                                                  applicable_year: 2017,
                                                }
    end
 
 
    context "if it runs again it doesn't create duplicates or throw errors" do
      before do
        invoke_task
      end
      it "does not create any more elements" do
        expect(imported_sic_rate_references.count).to eq(SicRateReference.all.count)        
      end
    end
 
    private
 
    def invoke_task
      Rake::Task["load_sic_rate_reference:update_sic_code"].invoke
    end
  end
 end