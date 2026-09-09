# frozen_string_literal: true

module Datatables
  # Table definition for the admin Notices page, listing every notice kind the
  # notifier engine can generate. Implements the table contract documented in
  # Datatables::FragmentRendering.
  #
  # It lives in the main app rather than the notifier engine because the
  # datatable it replaces does.
  class NoticesTable
    DELETE_CONFIRMATION = 'This will remove selected notices. Are you sure?'

    def param_key
      'notices'
    end

    # No column is user-sortable; mpi_indicator is the default-ordered column, so
    # its header carries the sort indicator and its cells the sort shading.
    def columns
      [
        { name: 'bulk_actions',    label: '',                 sortable: false, type: :bulk_actions_column, header: :bulk_all },
        { name: 'mpi_indicator',   label: 'Mpi Indicator',    sortable: false, type: :string, ordered: true },
        { name: 'title',           label: 'Title',            sortable: false, type: :string },
        { name: 'description',     label: 'Description',      sortable: false, type: :string },
        { name: 'recipient',       label: 'Recipient',        sortable: false, type: :string },
        { name: 'last_updated_at', label: 'Last Updated At',  sortable: false, type: :string },
        { name: 'actions',         label: 'Actions',          sortable: false, type: :string, width: '50px' }
      ]
    end

    def collection(_attributes)
      Notifier::NoticeKind.all
    end

    # No search box renders on this page.
    def global_search?
      false
    end

    def filters
      nil
    end

    def filter_scopes
      []
    end

    def date_filter
      nil
    end

    # mpi_indicator is not a NoticeKind field, so ordering by it leaves the
    # collection in its natural order.
    def default_order_column
      'mpi_indicator'
    end

    def column_index_offset
      0
    end

    def bulk_actions
      [{ label: 'Delete', url: routes.delete_notices_notice_kinds_path, confirm: DELETE_CONFIRMATION }]
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

    # The actions column and the checkbox column carry no exportable text; the
    # glyph column exports the notice number its link shows.
    def csv_headers
      columns[1..-2].map { |col| col[:label] }
    end

    def csv_row(notice_kind)
      [
        notice_kind.notice_number,
        notice_kind.title,
        notice_kind.description,
        recipient(notice_kind),
        last_updated_at(notice_kind)
      ]
    end

    def row_partial
      'notifier/notice_kinds/datatables/notices_row'
    end

    def recipient(notice_kind)
      notice_kind.recipient_klass_name.to_s.titleize
    end

    def last_updated_at(notice_kind)
      notice_kind.updated_at.in_time_zone('Eastern Time (US & Canada)').strftime('%m/%d/%Y %H:%M')
    end

    private

    def routes
      Notifier::Engine.routes.url_helpers
    end
  end
end
