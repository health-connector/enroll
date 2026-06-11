# frozen_string_literal: true

module Datatables
  # Page-math and rendering helpers for the refactored (Pagy + Stimulus)
  # datatables. Actions build their table object and call
  # render_datatable_fragment (Stimulus redraws) or datatable_locals
  # (initial full-page render of datatables/refactored/_table).
  module FragmentRendering
    extend ActiveSupport::Concern

    DEFAULT_PER_PAGE = 10
    PER_PAGE_OPTIONS = [10, 25, 50, 100].freeze

    private

    def render_datatable_fragment(table, url:)
      locals = datatable_locals(table, url: url)
      render partial: 'datatables/refactored/chrome', locals: locals, layout: false
    end

    def datatable_locals(table, url:)
      scoped = datatable_scoped(table)
      count = scoped.size
      pagy = datatable_pagy(count)
      records = scoped.order_by(datatable_order_criteria(table)).skip(pagy.offset).limit(pagy.limit)
      {
        table: table,
        pagy: pagy,
        records: records.to_a,
        url: url,
        search: params[:search].to_s,
        order: datatable_order_column(table),
        dir: datatable_order_dir
      }
    end

    # Filtered + searched collection, before ordering and pagination - the CSV
    # export iterates this in full.
    def datatable_scoped(table)
      scoped = table.collection(datatable_filter_attributes(table))
      scoped = scoped.datatable_search(params[:search]) if table.global_search? && params[:search].present?
      scoped
    end

    # The same attribute hash the legacy DataTables AJAX flow delivered to the
    # query wrappers via custom_attributes (e.g. {users: 'all', lock_unlock: 'locked'}).
    def datatable_filter_attributes(table)
      table.filter_scopes.index_with { |scope| params[scope].presence }.compact
    end

    def datatable_pagy(count)
      per = datatable_per_page
      last_page = [(count.to_f / per).ceil, 1].max
      page = params.fetch(:page, 1).to_i.clamp(1, last_page)
      Pagy.new(count: count, page: page, limit: per)
    end

    def datatable_per_page
      per = params[:per].to_i
      PER_PAGE_OPTIONS.include?(per) ? per : DEFAULT_PER_PAGE
    end

    def datatable_order_column(table)
      sortable = table.columns.select { |col| col[:sortable] }.map { |col| col[:name] }
      sortable.include?(params[:order]) ? params[:order] : sortable.first
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
