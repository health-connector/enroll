# frozen_string_literal: true

module Datatables
  # Table definition for the Broker Agencies admin datatable (Pagy + Stimulus
  # stack). Mirrors Effective::Datatables::BrokerAgencyDatatable: same columns,
  # same single-tab filter definition, and the same
  # BenefitSponsors::Organizations::Organization collection, so both stacks
  # return identical data while the :refactored_datatables flag is being
  # rolled out.
  #
  # Implements the table contract documented in Datatables::FragmentRendering.
  # Unlike UserAccountsTable, the collection is a plain Mongoid criteria
  # rather than a query wrapper.
  class BrokerAgenciesTable
    def param_key
      'broker_agencies'
    end

    # No column is user-sortable; the collection arrives pre-sorted by
    # legal_name, which legal_name's ordered flag surfaces as the sort
    # indicator (matching the legacy default order of [0, asc]).
    def columns
      [
        { name: 'legal_name',  label: 'Legal Name',  sortable: false, type: :string, ordered: true },
        { name: 'dba',         label: 'Dba',         sortable: false, type: :string },
        { name: 'fein',        label: 'FEIN',        sortable: false, type: :string },
        { name: 'entity_kind', label: 'Entity Kind', sortable: false, type: :string },
        { name: 'market_kind', label: 'Market Kind', sortable: false, type: :string }
      ]
    end

    # The legacy datatable ignores the filter attributes too - its only tab
    # ("All") narrows nothing.
    def collection(_attributes)
      BenefitSponsors::Organizations::Organization.broker_agency_profiles.order_by([:legal_name])
    end

    def global_search?
      true
    end

    def filters
      {
        broker_agencies: [
          { scope: 'all', label: 'All' }
        ],
        top_scope: :broker_agencies
      }
    end

    def filter_scopes
      [:broker_agencies]
    end

    def csv_headers
      columns.map { |col| col[:label] }
    end

    def csv_row(row)
      [
        row.legal_name,
        row.dba,
        row.fein,
        row.entity_kind.to_s.titleize,
        row.broker_agency_profile.market_kind.to_s.titleize
      ]
    end

    def row_partial
      'exchanges/hbx_profiles/datatables/broker_agencies_row'
    end
  end
end
