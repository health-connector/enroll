# frozen_string_literal: true

module Datatables
  # Table definition for the User Accounts admin datatable (Pagy + Stimulus
  # stack). Mirrors Effective::Datatables::UserAccountDatatable: same columns,
  # same nested filter definition, and the same Queries::UserDatatableQuery
  # collection wrapper, so both stacks return identical data while the
  # :refactored_datatables flag is being rolled out.
  #
  # The contract consumed by Datatables::FragmentRendering and the
  # app/views/datatables/_* partials:
  #   #param_key        - identifier used for DOM ids and the CSV filename
  #   #columns          - ordered column defs: name, label, sortable, type, width
  #   #collection(hash) - filterable collection (query wrapper or Mongoid criteria)
  #   #global_search?   - whether the search box renders
  #   #filters          - nested filter tab definition (legacy shape) or nil
  #   #csv_headers      - header row for the streamed CSV export
  #   #csv_row(record)  - plain-text cell values for one CSV row
  #   #row_partial      - partial rendered for each table row
  class UserAccountsTable
    def param_key
      'user_accounts'
    end

    def columns
      [
        { name: 'name',      label: 'USERNAME',   sortable: true,  type: :string },
        { name: 'ssn',       label: 'SSN',        sortable: false, type: :string },
        { name: 'dob',       label: 'DOB',        sortable: false, type: :string },
        { name: 'hbx_id',    label: 'HBX ID',     sortable: false, type: :integer },
        { name: 'email',     label: 'USER EMAIL', sortable: false, type: :string },
        { name: 'status',    label: 'Status',     sortable: false, type: :string },
        { name: 'role_type', label: 'Role Type',  sortable: false, type: :string },
        { name: 'actions',   label: 'Actions',    sortable: false, type: :string, width: '50px' }
      ]
    end

    def collection(attributes)
      Queries::UserDatatableQuery.new(attributes)
    end

    def global_search?
      true
    end

    def filters
      {
        lock_unlock: [
          { scope: 'locked', label: 'Locked' },
          { scope: 'unlocked', label: 'Unlocked' }
        ],
        users: [
          { scope: 'all', label: 'All', subfilter: :lock_unlock },
          { scope: 'all_employee_roles', label: 'Employee', subfilter: :lock_unlock },
          { scope: 'all_employer_staff_roles', label: 'Employer', subfilter: :lock_unlock },
          { scope: 'all_broker_roles', label: 'Broker', subfilter: :lock_unlock }
        ],
        top_scope: :users
      }
    end

    def filter_scopes
      [:users, :lock_unlock]
    end

    def status(row)
      return 'Unlocked' if row.locked_at.blank? && row.unlock_token.blank?

      'Locked'
    end

    # The actions column is excluded, matching the legacy client-side export
    # (buttons exported ':not(.col-actions)').
    def csv_headers
      columns[0..-2].map { |col| col[:label] }
    end

    def csv_row(row)
      person = row.person
      [
        row.oim_id,
        person && helpers.truncate(helpers.number_to_obscured_ssn(person.ssn)),
        person && helpers.format_date(person.dob),
        person&.hbx_id,
        row.email,
        status(row),
        row.roles.join(', ')
      ]
    end

    def row_partial
      'exchanges/hbx_profiles/datatables/user_accounts_row'
    end

    private

    def helpers
      ApplicationController.helpers
    end
  end
end
