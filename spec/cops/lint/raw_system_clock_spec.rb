# frozen_string_literal: true

require 'rubocop'
require 'rubocop/rspec/support'
require_relative '../../../cops/lint/raw_system_clock'

RSpec.describe RuboCop::Cop::Lint::RawSystemClock do
  include RuboCop::RSpec::ExpectOffense

  subject(:cop) { described_class.new(RuboCop::Config.new) }

  it "registers an offense for Date.today" do
    expect_offense(<<~RUBY)
      effective_on = Date.today
                     ^^^^^^^^^^ Lint/RawSystemClock: Avoid `Date.today`, it follows the server clock. Use `TimeKeeper.date_of_record` for a business date or `Time.current` for a timestamp.
    RUBY
  end

  it "registers an offense for Time.now" do
    expect_offense(<<~RUBY)
      submitted_at = Time.now
                     ^^^^^^^^ Lint/RawSystemClock: Avoid `Time.now`, it follows the server clock. Use `TimeKeeper.date_of_record` for a business date or `Time.current` for a timestamp.
    RUBY
  end

  it "registers an offense for DateTime.now" do
    expect_offense(<<~RUBY)
      determined_at = DateTime.now
                      ^^^^^^^^^^^^ Lint/RawSystemClock: Avoid `DateTime.now`, it follows the server clock. Use `TimeKeeper.date_of_record` for a business date or `Time.current` for a timestamp.
    RUBY
  end

  it "registers an offense when the constant is top level scoped" do
    expect_offense(<<~RUBY)
      effective_on = ::Date.today
                     ^^^^^^^^^^^^ Lint/RawSystemClock: Avoid `::Date.today`, it follows the server clock. Use `TimeKeeper.date_of_record` for a business date or `Time.current` for a timestamp.
    RUBY
  end

  it "accepts TimeKeeper for a business date" do
    expect_no_offenses("effective_on = TimeKeeper.date_of_record")
  end

  it "accepts Time.current for a timestamp" do
    expect_no_offenses("submitted_at = Time.current")
  end

  it "accepts a timestamp read off a record" do
    expect_no_offenses("stamped = enrollment.created_at")
  end
end
