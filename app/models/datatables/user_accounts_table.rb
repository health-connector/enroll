# frozen_string_literal: true

module Datatables
  # Table definition for the User Accounts admin datatable. Wraps the filter-tab
  # attributes in Queries::UserDatatableQuery and implements the table contract
  # documented in Datatables::FragmentRendering.
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

    def date_filter
      nil
    end

    def buttons
      %w[csv excel]
    end

    def per_page_options
      [10, 25, 50, 100]
    end

    def status(row)
      return 'Unlocked' if row.locked_at.blank? && row.unlock_token.blank?

      'Locked'
    end

    # The actions column is excluded from the export.
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
