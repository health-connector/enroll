# frozen_string_literal: true

module BenefitSponsors
  module Datatables
    # Table definition for the employer portal's Coverage Reports page.
    # Implements the table contract documented in ::Datatables::FragmentRendering,
    # except the CSV methods: the page renders no export button, and its
    # full-period CSV is the Download button served by
    # BenefitSponsors::Profiles::Employers::EmployerProfilesController#coverage_reports.
    #
    # The collection is BenefitSponsors::LegacyCoverageReportAdapter, whose
    # order_by, skip and limit all return self. It therefore satisfies the
    # collection interface without paginating: every row of the selected billing
    # period renders at once, while the info line and pager still count and
    # divide by the selected page length. The adapter also drops any sponsored
    # benefit carrying more than 100 enrollments.
    class CoverageReportsTable
      def initialize(employer_profile, billing_date)
        @employer_profile = employer_profile
        @billing_date = billing_date
      end

      def param_key
        'coverage_reports'
      end

      # No column is user-sortable; full_name is the default-ordered column
      # (index 0, asc), so its header carries the sort indicator and its cells the
      # sort shading.
      def columns
        [
          { name: 'full_name',     label: 'Employee Profile',   sortable: false, type: :string, ordered: true },
          { name: 'title',         label: 'Benefit Package',    sortable: false, type: :string },
          { name: 'coverage_kind', label: 'Insurance Coverage', sortable: false, type: :string },
          { name: 'cost',          label: 'COST',               sortable: false, type: :string }
        ]
      end

      def collection(_attributes)
        BenefitSponsors::Queries::CoverageReportsQuery.new(@employer_profile, @billing_date).execute
      end

      def global_search?
        true
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
        [10, 25, 50, ::Datatables::FragmentRendering::ALL_PER_PAGE]
      end

      def layout
        ::Datatables::Layouts::SEARCH_ONLY
      end

      def row_partial
        'benefit_sponsors/profiles/employers/employer_profiles/datatables/coverage_reports_row'
      end

      def product_title(product_id)
        products[product_id]
      end

      def issuer_name(issuer_profile_id)
        issuers[issuer_profile_id]
      end

      private

      # Shop products whose application period starts in the previous, current or
      # next year - the window the report's rows can fall in.
      def current_products
        @current_products ||= begin
          current_year = TimeKeeper.date_of_record.year
          starts = [current_year - 1, current_year, current_year + 1].map { |year| Date.new(year, 1, 1) }
          BenefitMarkets::Products::Product.aca_shop_market
                                           .by_state(Settings.aca.state_abbreviation)
                                           .where(:"application_period.min".in => starts)
        end
      end

      def products
        @products ||= current_products.each_with_object({}) { |product, result| result[product.id] = product.title }
      end

      def issuers
        @issuers ||= current_products.map(&:issuer_profile).uniq.each_with_object({}) do |issuer, result|
          result[issuer.id] = issuer.legal_name
        end
      end
    end
  end
end
