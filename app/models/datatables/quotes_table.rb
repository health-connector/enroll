# frozen_string_literal: true

module Datatables
  # Table definition for the broker portal's Quotes datatable. Implements the
  # table contract documented in Datatables::FragmentRendering. The broker whose
  # quotes are listed is supplied by the controller from the authorized route
  # broker, so the collection depends on no process-wide state.
  class QuotesTable
    EMPLOYER_TYPES = %w[client prospect].freeze
    STATES = %w[draft published claimed].freeze

    def initialize(broker_role_id)
      @broker_role_id = broker_role_id
    end

    def param_key
      'quotes'
    end

    # No column is user-sortable; employer_name is the default-ordered column
    # (index 0, asc), so its header carries the sort indicator and its cells the
    # sort shading.
    def columns
      [
        { name: 'employer_name',  label: 'Employer Name',  sortable: false, type: :string, ordered: true },
        { name: 'employer_type',  label: 'Employer Type',  sortable: false, type: :string },
        { name: 'quote',          label: 'Quote',          sortable: false, type: :string },
        { name: 'effective_date', label: 'Effective Date', sortable: false, type: :string },
        { name: 'claim_code',     label: 'Claim Code',     sortable: false, type: :string },
        { name: 'family_count',   label: 'Family Count',   sortable: false, type: :string },
        { name: 'state',          label: 'State',          sortable: false, type: :string },
        { name: 'actions',        label: 'Actions',        sortable: false, type: :string, width: '50px' }
      ]
    end

    # An 'all' selection on either tab level narrows nothing.
    def collection(attributes)
      quotes = Quote.where(broker_role_id: @broker_role_id)
      employer_type = attributes[:employer_types]
      state = attributes[:states]
      quotes = quotes.where(employer_type: employer_type) if EMPLOYER_TYPES.include?(employer_type)
      quotes = quotes.where(aasm_state: state) if STATES.include?(state)
      quotes
    end

    def global_search?
      true
    end

    def filters
      {
        states: [
          { scope: 'all', label: 'All' },
          { scope: 'draft', label: 'Draft' },
          { scope: 'published', label: 'Published' },
          { scope: 'claimed', label: 'Claimed' }
        ],
        employer_types: [
          { scope: 'all', label: 'All' },
          { scope: 'prospect', label: 'Prospect', subfilter: :states }
        ],
        top_scope: :employer_types
      }
    end

    def filter_scopes
      [:employer_types, :states]
    end

    def date_filter
      nil
    end

    # employer_name is a real Quote field, so this order applies (on most other
    # tables the equivalent order is a no-op).
    def default_order_column
      'employer_name'
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

    def layout
      Datatables::Layouts::STANDARD
    end

    # The actions column is excluded from the export.
    def csv_headers
      columns[0..-2].map { |col| col[:label] }
    end

    def csv_row(row)
      [
        employer_name(row),
        row.employer_type,
        row.quote_name.titleize,
        row.start_on,
        row.claim_code,
        row.quote_households.count,
        row.aasm_state
      ]
    end

    def row_partial
      'broker_agencies/quotes/datatables/quotes_row'
    end

    def employer_name(quote)
      quote.employer_profile.present? ? quote.employer_profile.legal_name : quote.employer_name
    end

    # A draft quote has nothing published to view yet.
    def published_quote_link_type(quote)
      quote.aasm_state == 'draft' ? 'disabled' : 'static'
    end
  end
end
