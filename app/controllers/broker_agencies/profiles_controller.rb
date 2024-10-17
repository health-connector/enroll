class BrokerAgencies::ProfilesController < ApplicationController
  include Acapi::Notifiers
  include ::Config::AcaConcern
  include ::DataTablesAdapter

  layout 'single_column'

  EMPLOYER_DT_COLUMN_TO_FIELD_MAP = {
    "2"     => "legal_name",
    "4"     => "employer_profile.aasm_state",
    "5"     => "employer_profile.plan_years.start_on"
  }
end
