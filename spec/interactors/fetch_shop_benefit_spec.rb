# frozen_string_literal: true

require 'rails_helper'
require "./spec//shared_context/setup_shop_families_enrollments"

describe FetchShopBenefit, :dbclean => :after_each do
  include_context "setup shop families enrollments"

  context "when shopping in OE" do
    it "should fetch employee_role" do
      context = described_class.call(employee_role: employee_role, market_kind: "shop")
      expect(context.benefit_package).to be_truthy
    end
  end
end
