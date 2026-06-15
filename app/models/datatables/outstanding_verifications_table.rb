# frozen_string_literal: true

module Datatables
  # Table definition for the Outstanding Verifications admin datatable (Pagy +
  # Stimulus stack). Mirrors Effective::Datatables::OutstandingVerificationDataTable:
  # same columns, same documents-uploaded filter tabs, the same
  # "Verification Due Date Range" date filter, and the same
  # Queries::OutstandingVerificationDatatableQuery collection wrapper, so both
  # stacks return identical data while the :refactored_datatables flag is being
  # rolled out.
  #
  # Implements the table contract documented in Datatables::FragmentRendering.
  # This is the first table to declare a date filter and to render the print
  # button (buttons: excel, csv, print).
  class OutstandingVerificationsTable
    def param_key
      'outstanding_verifications'
    end

    # name/documents_uploaded/verification_due are sortable to match the legacy
    # column flags (and the default order [0, asc] surfaces sorting_asc on the
    # name header). The sort itself is effectively a no-op: the query wrapper
    # only applies order_by while a search is active, and the column names are
    # not real Family fields - the legacy stack reorders nothing here either.
    def columns
      [
        { name: 'name',               label: 'Name',               sortable: true,  type: :string },
        { name: 'ssn',                label: 'SSN',                sortable: false, type: :string },
        { name: 'dob',                label: 'DOB',                sortable: false, type: :string },
        { name: 'hbx_id',             label: 'HBX ID',             sortable: false, type: :integer },
        { name: 'count',              label: 'Count',              sortable: false, type: :string, width: '100px' },
        { name: 'documents_uploaded', label: 'Documents Uploaded', sortable: true,  type: :string },
        { name: 'verification_due',   label: 'Verification Due',   sortable: true,  type: :string },
        { name: 'actions',            label: 'Actions',            sortable: false, type: :string, width: '50px' }
      ]
    end

    def collection(attributes)
      Queries::OutstandingVerificationDatatableQuery.new(attributes)
    end

    def global_search?
      true
    end

    def filters
      {
        documents_uploaded: [
          { scope: 'vlp_fully_uploaded', label: 'Fully Uploaded', title: 'Documents to review for all outstanding verifications' },
          { scope: 'vlp_partially_uploaded', label: 'Partially Uploaded', title: 'Documents to review for some outstanding verifications' },
          { scope: 'vlp_none_uploaded', label: 'None Uploaded', title: 'No documents to review' },
          { scope: 'all', label: 'All', title: 'All outstanding verifications' }
        ],
        top_scope: :documents_uploaded
      }
    end

    # custom_datatable_date_from/to ride along in the same attribute hash the
    # filter tabs use; the query wrapper's build_scope reads them to apply
    # Family.min_verification_due_date_range.
    def filter_scopes
      [:documents_uploaded, :custom_datatable_date_from, :custom_datatable_date_to]
    end

    # Label for the date-range filter block (legacy date_filter_name_definition).
    def date_filter
      'Verification Due Date Range'
    end

    # Rendered (and in this order) by the buttons partial. Print is unique to
    # this page among the migrated tables.
    def buttons
      %w[excel csv print]
    end

    # Legacy length menu: render_datatable was passed lengthMenu
    # [[10, 25, 50], [10, 25, 50]] - no 100 option, unlike the default tables.
    def per_page_options
      [10, 25, 50]
    end

    # The actions column is excluded, matching the legacy client-side export
    # (buttons exported ':not(.col-actions)').
    def csv_headers
      columns[0..-2].map { |col| col[:label] }
    end

    def csv_row(row)
      person = row.primary_applicant.person
      [
        person.full_name,
        helpers.truncate(helpers.number_to_obscured_ssn(person.ssn)),
        helpers.format_date(person.dob),
        person.hbx_id,
        row.active_family_members.size,
        row.vlp_documents_status,
        helpers.format_date(row.best_verification_due_date) || helpers.format_date(TimeKeeper.date_of_record + 95.days)
      ]
    end

    def row_partial
      'exchanges/hbx_profiles/datatables/outstanding_verifications_row'
    end

    private

    def helpers
      ApplicationController.helpers
    end
  end
end
