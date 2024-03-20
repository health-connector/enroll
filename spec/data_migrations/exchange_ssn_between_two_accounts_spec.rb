# frozen_string_literal: true

require "rails_helper"
require File.join(Rails.root, "app", "data_migrations", "exchange_ssn_between_two_accounts")

describe ChangeFein do
  let(:given_task_name) { "exchange_ssn_between_two_accounts" }
  subject { ExchangeSsnBetweenTwoAccounts.new(given_task_name, double(:current_scope => nil)) }

  describe "given a task name" do
    it "has the given task name" do
      expect(subject.name).to eql given_task_name
    end
  end

  describe "change ssn if both people exits and both have ssn" do
    let(:person1){ FactoryBot.create(:person, first_name: 'bob', ssn: "123123123")}
    let(:person2){FactoryBot.create(:person,ssn: "456456456")}

    around do |example|
      ClimateControl.modify hbx_id_1: person1.hbx_id, hbx_id_2: person2.hbx_id do
        example.run
        DatabaseCleaner.clean
      end
    end

    it "should change ssn of two people" do
      ssn1 = person1.reload.ssn
      ssn2 = person2.reload.ssn
      subject.migrate
      expect(person2.reload.ssn).to eq ssn1
      expect(person1.reload.ssn).to eq ssn2
    end
  end

  describe "not change ssn if either people not exist" do
    let(:person1){ FactoryBot.create(:person,ssn: "123123123")}
    let(:person2){FactoryBot.create(:person,ssn: "456456456")}

    around do |example|
      ClimateControl.modify hbx_id_1: '', hbx_id_2: person2.hbx_id do
        example.run
        DatabaseCleaner.clean
      end
    end

    it "should change ssn of two people" do
      ssn1 = person1.reload.ssn
      ssn2 = person2.reload.ssn
      subject.migrate
      expect(person1.reload.ssn).to eq ssn1
      expect(person2.reload.ssn).to eq ssn2
    end
  end

  describe "not change ssn if either people has no ssn" do
    let(:person1){ FactoryBot.create(:person,ssn: "123123123")}
    let(:person2){FactoryBot.create(:person)}

    around do |example|
      ClimateControl.modify hbx_id_1: person1.hbx_id, hbx_id_2: person2.hbx_id do
        example.run
        DatabaseCleaner.clean
      end
    end

    it "should change ssn of two people" do
      ssn1 = person1.reload.ssn
      ssn2 = person2.reload.ssn
      subject.migrate
      expect(person1.reload.ssn).to eq ssn1
      expect(person2.reload.ssn).to eq ssn2
    end
  end
end
