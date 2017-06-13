require 'rails_helper'

RSpec.describe SicRateReference, type: :model do
  subject { SicRateReference.new }


  it "has a valid factory" do
    expect(create(:sic_rate_reference)).to be_valid
  end

  
  it { is_expected.to validate_presence_of :sic}
  it { is_expected.to validate_presence_of :hios_id}
  it { is_expected.to validate_presence_of :cost_ratio}
  it { is_expected.to validate_presence_of :applicable_year}
end
