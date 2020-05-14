require"rails_helper"
require File.join(Rails.root, "app", "data_migrations", "golden_seed")

describe GoldenSeed, dbclean: :after_each do

  let(:given_task_name) { "golden_seed" }
  subject { GoldenSeed.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end

    describe "instance variables" do
      it "sets organization_collection as instance variable" do

      end
      it "sets benefit_sponsorships as instance variable" do

      end
      it "sets benefit_applications as instance variable" do

      end
    end
  end

  describe "updating benefit applications", dbclean: :after_each do
    before :each do
      ['benefit_sponsorship_ids', 'coverage_start_on', 'coverage_end_on'].each do |var|
        ENV[var] = nil
      end
    end

    it "should run without errors" do
      subject.migrate
    end

    describe "requirements" do
      before :each do
        ['benefit_sponsorship_ids', 'coverage_start_on', 'coverage_end_on'].each do |var|
          ENV[var] = nil
        end
      end

      it "should modify benefit application coverage start_on" do

      end

      it "should modify benefit application coverage end_on" do

      end

      it "should modify benefit application open_enrollment_start_on" do

      end

      it "should modify benefit application open_enrollment_end_on" do


      end

      it "should modify recalculate the appropriate prices" do

      end
    end
  end
end
