# frozen_string_literal: true

module Datatables
  # Page-math and rendering helpers for the Pagy + Stimulus datatables. Actions
  # build their table object and call render_datatable_fragment (Stimulus
  # redraws) or datatable_locals (initial full-page render of
  # datatables/_datatable).
  #
  # The table contract consumed here and by the app/views/datatables/_*
  # partials (implemented by the Datatables::*Table POROs):
  #   #param_key        - identifier used for DOM ids and the CSV filename
  #   #columns          - ordered column defs: name, label, sortable, type
  #                       (-> col-<name> / col-<type> th and td classes);
  #                       optional width (inline th width) and ordered
  #                       (collection arrives pre-sorted ascending by this
  #                       column - renders the sort indicator on a
  #                       non-sortable header)
  #   #collection(hash) - filterable collection given the filter-tab attribute
  #                       hash: a query wrapper (e.g. Queries::UserDatatableQuery)
  #                       or a plain Mongoid criteria - anything responding to
  #                       order_by/skip/limit/size and, when global_search? is
  #                       true, datatable_search
  #   #global_search?   - whether the search box renders
  #   #filters          - nested filter tab definition or nil
  #   #filter_scopes    - filter param keys collected into #collection's hash
  #                       (includes custom_datatable_date_from/to when the table
  #                       has a date filter)
  #   #date_filter      - label for the date-range filter block, or nil when the
  #                       table has no date filter
  #   #default_order_column - column name whose header shows the sort indicator on
  #                       load (and which orders the collection when no user sort
  #                       is active); may name a non-visible field (e.g. created_at)
  #                       so that no visible header is highlighted
  #   #column_index_offset - amount added to each column's positional index for the
  #                       th data-column-index attribute, accounting for any
  #                       leading non-rendered legacy columns (usually 0)
  #   #bulk_actions     - ordered bulk-action configs ({label, url, confirm}) for
  #                       the dropdown prepended into datatables/_buttons; [] when
  #                       the table has no bulk actions
  #   #disable_selectric? - whether the Stimulus controller suppresses page-global
  #                       selectric (true for tables whose row actions inject forms
  #                       with native selects that must stay reachable)
  #   #search_column(collection, name, value) - applies a per-column filter (only
  #                       called for columns declaring a filter:); returns the
  #                       narrowed collection
  #   #buttons          - ordered export/print button keys (e.g. %w[csv excel]
  #                       or %w[excel csv print]) rendered by datatables/_buttons
  #   #per_page_options - the page-length menu values, e.g.
  #                       [10, 25, 50, 100]; the first is the default page size
  #   #csv_headers      - header row for the streamed CSV export
  #   #csv_row(record)  - plain-text cell values for one CSV row
  #   #row_partial      - partial rendered for each table row with locals
  #                       row, table, row_class
  module FragmentRendering
    extend ActiveSupport::Concern

    private

    def render_datatable_fragment(table, url:)
      locals = datatable_locals(table, url: url)
      render partial: 'datatables/table', locals: locals, layout: false
    end

    def datatable_locals(table, url:)
      scoped = datatable_scoped(table)
      count = scoped.size
      pagy = datatable_pagy(count, table)
      records = scoped.order_by(datatable_order_criteria(table)).skip(pagy.offset).limit(pagy.limit)
      {
        table: table,
        pagy: pagy,
        records: records.to_a,
        url: url,
        search: params[:search].to_s,
        order: datatable_order_column(table),
        dir: datatable_order_dir,
        date_from: params[:custom_datatable_date_from].to_s,
        date_to: params[:custom_datatable_date_to].to_s,
        column_filters: datatable_column_filters(table)
      }
    end

    # Filtered + searched collection, before ordering and pagination - the CSV
    # export iterates this in full.
    def datatable_scoped(table)
      scoped = table.collection(datatable_filter_attributes(table))
      scoped = scoped.datatable_search(params[:search]) if table.global_search? && params[:search].present?
      datatable_column_filters(table).each { |name, value| scoped = table.search_column(scoped, name, value) }
      scoped
    end

    # Active per-column filter values keyed by column name, read from the
    # columns[<name>]=<value> params the controller adds for filter columns.
    def datatable_column_filters(table)
      table.columns.each_with_object({}) do |col, filters|
        next unless col[:filter]

        value = params.dig(:columns, col[:name])
        filters[col[:name]] = value if value.present?
      end
    end

    # Builds the filter-attribute hash the query wrappers consume
    # (e.g. {users: 'all', lock_unlock: 'locked'}).
    def datatable_filter_attributes(table)
      table.filter_scopes.index_with { |scope| params[scope].presence }.compact
    end

    def datatable_pagy(count, table)
      per = datatable_per_page(table)
      last_page = [(count.to_f / per).ceil, 1].max
      page = params.fetch(:page, 1).to_i.clamp(1, last_page)
      Pagy.new(count: count, page: page, limit: per)
    end

    def datatable_per_page(table)
      options = table.per_page_options
      per = params[:per].to_i
      options.include?(per) ? per : options.first
    end

    def datatable_order_column(table)
      sortable = table.columns.select { |col| col[:sortable] }.map { |col| col[:name] }
      sortable.include?(params[:order]) ? params[:order] : table.default_order_column
    end

    def datatable_order_dir
      params[:dir] == 'desc' ? 'desc' : 'asc'
    end

    def datatable_order_criteria(table)
      column = datatable_order_column(table)
      return {} if column.blank?

      { column => (datatable_order_dir == 'desc' ? -1 : 1) }
    end
  end
end
