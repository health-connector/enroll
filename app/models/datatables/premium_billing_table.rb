# frozen_string_literal: true

module Datatables
  # Table definition for the employer portal's premium billing report.
  # Implements the table contract documented in Datatables::FragmentRendering,
  # except the CSV methods: this report renders no export button, because its
  # full-dataset CSV is served by Employers::PremiumStatementsController#show.
  #
  # The report reads one billing period at a time. The enrollment ids for that
  # period come from Queries::EmployerPremiumStatement; Queries::PremiumBillingReportQuery
  # turns them into the families that hold them, and EnrollmentRows expands each
  # page of families back into enrollments (see its comment).
  class PremiumBillingTable
    def initialize(employer_profile, billing_date)
      @employer_profile = employer_profile
      @billing_date = billing_date
    end

    def param_key
      'premium_billing'
    end

    # No column is user-sortable; full_name is the default-ordered column
    # (index 0, asc), so its header carries the sort indicator and its cells the
    # sort shading.
    def columns
      [
        { name: 'full_name',     label: 'Employee Profile',    sortable: false, type: :string, ordered: true },
        { name: 'title',         label: 'Benefit Package',     sortable: false, type: :string },
        { name: 'coverage_kind', label: 'Insurance Coverage',  sortable: false, type: :string },
        { name: 'cost',          label: 'COST',                sortable: false, type: :string }
      ]
    end

    def collection(_attributes)
      EnrollmentRows.new(Queries::PremiumBillingReportQuery.new(hbx_enrollment_ids), hbx_enrollment_ids)
    end

    def global_search?
      true
    end

    # The report's only filter tab narrowed nothing and was hidden on the page,
    # so no tab bar renders.
    def filters
      nil
    end

    def filter_scopes
      []
    end

    def date_filter
      nil
    end

    def default_order_column
      'full_name'
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
      []
    end

    # -1 offers every row on one page, labelled "All".
    def per_page_options
      [10, 25, 50, Datatables::FragmentRendering::ALL_PER_PAGE]
    end

    def layout
      Datatables::Layouts::SEARCH_ONLY
    end

    def row_partial
      'employers/premium_statements/datatables/premium_billing_row'
    end

    # Enrollment ids covering the selected billing period.
    def hbx_enrollment_ids
      @hbx_enrollment_ids ||= begin
        statement = Queries::EmployerPremiumStatement.new(@employer_profile, @billing_date).execute
        statement.nil? ? [] : statement.hbx_enrollments.map(&:_id)
      end
    end

    # Paginates over the families holding the period's enrollments while
    # rendering one row per enrollment: the page counts and the info line count
    # families, and each page's families are expanded into the enrollments that
    # fall in the period. A family holding two enrollments therefore renders two
    # rows.
    class EnrollmentRows
      def initialize(families, hbx_enrollment_ids, skip: nil, limit: nil)
        @families = families
        @hbx_enrollment_ids = hbx_enrollment_ids
        @skip = skip
        @limit = limit
      end

      def datatable_search(string)
        chain(@families.datatable_search(string))
      end

      # The query wrapper stores the order criteria without applying it, so the
      # collection keeps its own enrollment-id order.
      def order_by(criteria)
        chain(@families.order_by(criteria))
      end

      def skip(num)
        chain(@families, skip: num)
      end

      def limit(num)
        chain(@families, limit: num)
      end

      def size
        @families.size
      end

      def to_a
        paginated_families.flat_map { |family| family.households.flat_map(&:hbx_enrollments) }
                          .select { |enrollment| @hbx_enrollment_ids.include?(enrollment.id) }
      end

      private

      def chain(families, skip: @skip, limit: @limit)
        self.class.new(families, @hbx_enrollment_ids, skip: skip, limit: limit)
      end

      # The wrapper's skip returns the underlying Mongoid criteria, so it is
      # always called (nil skips none) to leave a criteria to iterate.
      def paginated_families
        scope = @families.skip(@skip.to_i)
        @limit ? scope.limit(@limit) : scope
      end
    end
  end
end
