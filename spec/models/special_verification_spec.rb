# frozen_string_literal: true

require 'rails_helper'

describe SpecialVerification do

  it { should validate_presence_of :due_date }
  it { should validate_presence_of :verification_type }

  let(:params) do
    {
      due_date: TimeKeeper.date_of_record + 95.days,
      verification_type: "Citizenship",
      updated_by: double("AdminUser"),
      type: "admin"
    }
  end

  let(:subject) { SpecialVerification.new(**params)}

  it "should be valid record" do
    expect(subject.valid?).to eq true
  end

  it "should raise an error when saved without parent object" do
    expect {subject.save}.to raise_error(Mongoid::Errors::NoParent)
  end
end
