# frozen_string_literal: true

require "rails_helper"

describe BrokerAgencies::ApplicantPolicy, dbclean: :after_each do
  subject { described_class }
  let(:account_holder) { double("AccountHolder") }
  # ensure user always responds to :person to avoid unexpected message errors
  let(:user) { double("User", person: nil) }
  let(:policy) { subject.new(user, account_holder) }

  context "when user is shop market admin" do
    let(:user) { double("User", person: nil) }

    before do
      allow(policy).to receive(:shop_market_admin?).and_return(true)
    end

    it "permits index, edit, and update" do
      expect(policy.index?).to be_truthy
      expect(policy.edit?).to be_truthy
      expect(policy.update?).to be_truthy
    end
  end

  context "when user is a primary broker" do
    let(:broker_role) { double("BrokerRole", is_primary_broker?: true) }
    let(:person) { double("Person", broker_role: broker_role) }
    let(:account_holder) { double("AccountHolder", person: person) }
    # user needn't provide a person here (account_holder.person is used), but keep person method available
    let(:user) { double("User", person: person) }

    before do
      allow(policy).to receive(:shop_market_admin?).and_return(false)
    end

    it "permits index, edit, and update" do
      expect(policy.index?).to be_truthy
      expect(policy.edit?).to be_truthy
      expect(policy.update?).to be_truthy
    end
  end

  context "when user is neither shop market admin nor primary broker" do
    let(:broker_role) { double("BrokerRole", is_primary_broker?: false) }
    let(:person) { double("Person", broker_role: broker_role) }
    let(:account_holder) { double("AccountHolder", person: person) }
    let(:user) { double("User", person: nil) }

    before do
      allow(policy).to receive(:shop_market_admin?).and_return(false)
    end

    it "denies index, edit, and update" do
      expect(policy.index?).to be_falsey
      expect(policy.edit?).to be_falsey
      expect(policy.update?).to be_falsey
    end
  end

  context "when account_holder has no broker_role and is not shop market admin" do
    let(:person) { double("Person", broker_role: nil) }
    let(:account_holder) { double("AccountHolder", person: person) }
    let(:user) { double("User", person: nil) }

    before do
      allow(policy).to receive(:shop_market_admin?).and_return(false)
    end

    it "denies index, edit, and update" do
      expect(policy.index?).to be_falsey
      expect(policy.edit?).to be_falsey
      expect(policy.update?).to be_falsey
    end
  end
end