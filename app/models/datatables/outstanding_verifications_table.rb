# frozen_string_literal: true

module Datatables
  # Table definition for the Outstanding Verifications admin datatable.
  # Implements the table contract documented in Datatables::FragmentRendering;
  # it is the one table that declares a date-range filter and renders the print
  # button (buttons: excel, csv, print).
  class OutstandingVerificationsTable
    def param_key
      'outstanding_verifications'
    end

    # name/documents_uploaded/verification_due render as sortable, and name is
    # the default-ordered column (its header shows sorting_asc on load). The sort
    # is a visual no-op, though: the query wrapper only applies order_by while a
    # search is active, and these column names are not real Family fields, so
    # nothing actually reorders.
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

    # Label for the date-range filter block.
    def date_filter
      'Verification Due Date Range'
    end

    # Rendered in this order by the buttons partial; this is the one table with
    # a print button.
    def buttons
      %w[excel csv print]
    end

    # This page's length menu is 10/25/50 (no 100, unlike the default tables).
    def per_page_options
      [10, 25, 50]
    end

    # The actions column is excluded from the export.
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
