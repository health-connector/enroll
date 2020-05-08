require"rails_helper"
require File.join(Rails.root, "app", "data_migrations", "golden_seed")

describe GoldenSeed, dbclean: :after_each do

  let(:given_task_name) { "golden_seed" }
  subject { GoldenSeed.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "create seed data for testing", dbclean: :after_each do
    before :each do
      ['input_csv_filename'].each do |var|
        ENV[var] = nil
      end
    end

    it "should run without errors" do
      subject.migrate
    end

    describe "requirements" do
      before :each do
        ['input_csv_filename'].each do |var|
          ENV[var] = nil
        end
      end

      it "should create employers" do

      end

      it "should create census employees belonging to a specific employer/employee_role" do

      end

      it "should create dependents for a family" do


      end

      it "should not modify existing plans" do

      end

      it "should create benefit applications for a given employer benefit package" do

      end
    end
  end
end
