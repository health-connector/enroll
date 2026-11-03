# frozen_string_literal: true

require 'rails_helper'

describe Forms::ResidentCandidate, "#match_person", dbclean: :after_each do
  let!(:db_person) { Person.create!(first_name: "Joe", last_name: "Kramer", dob: "1993-03-30", ssn: '') }

  subject do
    Forms::ResidentCandidate.new({
                                   :dob => "1993-03-30",
                                   :first_name => "Joe",
                                   :last_name => "Kramer",
                                   :gender => "m",
                                   :user_id => 20,
                                   :is_applying_coverage => false
                                 })
  end

  it 'matches the person by last_name, first name and dob if there is no ssn' do
    expect(subject.match_person).to eq db_person
  end

  it 'treats regex metacharacters in names as literal text' do
    subject.first_name = "J.e"
    subject.last_name = "Kr.mer"
    expect(subject.match_person).to be_nil
  end

  it 'does not raise on an unbalanced parenthesis in a name' do
    subject.first_name = "Joe("
    expect { subject.match_person }.not_to raise_error
  end
end
