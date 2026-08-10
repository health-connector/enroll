# frozen_string_literal: true

module Datatables
  # Table definition for the Broker Agencies admin datatable. Implements the
  # table contract documented in Datatables::FragmentRendering. Unlike
  # UserAccountsTable, the collection is a plain Mongoid criteria rather than a
  # query wrapper.
  class BrokerAgenciesTable
    def param_key
      'broker_agencies'
    end

    # No column is user-sortable; the collection arrives pre-sorted by
    # legal_name, and legal_name's ordered flag surfaces that as the sort
    # indicator on its (non-clickable) header.
    def columns
      [
        { name: 'legal_name',  label: 'Legal Name',  sortable: false, type: :string, ordered: true },
        { name: 'dba',         label: 'Dba',         sortable: false, type: :string },
        { name: 'fein',        label: 'FEIN',        sortable: false, type: :string },
        { name: 'entity_kind', label: 'Entity Kind', sortable: false, type: :string },
        { name: 'market_kind', label: 'Market Kind', sortable: false, type: :string }
      ]
    end

    # The only tab ("All") narrows nothing, so the filter attributes are ignored.
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

    def date_filter
      nil
    end

    # No column is user-sortable and the collection carries its own legal_name
    # order, so no header is the active sort.
    def default_order_column
      nil
    end

    def column_index_offset
      0
    end

    def bulk_actions
      []
    end

    def disable_selectric?
      false
    end

    def buttons
      %w[csv excel]
    end

    def per_page_options
      [10, 25, 50, 100]
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
