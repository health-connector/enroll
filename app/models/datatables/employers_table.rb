# frozen_string_literal: true

module Datatables
  # Table definition for the Employers / Employer Invoice admin datatable (both
  # tabs render this; both back onto BenefitSponsorsEmployerDatatable). Implements
  # the table contract documented in Datatables::FragmentRendering and adds the
  # two capabilities the scaffold gained in this phase: bulk actions (the dropdown
  # in #bulk_actions, the per-row checkbox column) and a per-column select filter
  # (source_kind, via #search_column).
  class EmployersTable
    include Config::AcaModelConcern

    SOURCE_KINDS = ([:all] + BenefitSponsors::BenefitSponsorships::BenefitSponsorship::SOURCE_KINDS).freeze

    # Whitelist of scope/method names a filter attribute is permitted to invoke on
    # the collection. Filter values arrive in query params, so the collection
    # method derived from them is checked against this list before send - an
    # injection guard.
    ALLOWED_METHODS = %w[
      benefit_sponsorship_applicant benefit_application_enrolling
      benefit_application_enrolled employer_attestations
      all benefit_application_enrolling_initial benefit_application_pending
      benefit_application_enrolling_initial_oe benefit_application_initial_binder_paid
      benefit_application_initial_binder_pending benefit_application_enrolling_renewing
      benefit_application_renewal_pending benefit_application_enrolling_renewing_oe
      benefit_application_enrolled benefit_application_suspended
      submitted pending approved denied
    ].freeze

    FILTER_MAPPINGS = {
      employers: :filter_by_employers,
      enrolling: :filter_by_enrolling,
      enrolled: :filter_by_enrolled,
      employer_attestations: :filter_by_employer_attestations,
      upcoming_dates: :filter_by_upcoming_dates,
      attestations: :filter_by_attestations
    }.freeze

    def param_key
      'employers'
    end

    # Column 0 in the legacy table is a hidden created_at column, so the visible
    # columns carry data-column-index 1..n; this offset reproduces that numbering.
    def column_index_offset
      1
    end

    # bulk_actions is the checkbox column (its header renders the check-all box).
    # source_kind carries the only per-column select filter in the app. The
    # attestation_status column appears only when employer attestations are on,
    # matching the legacy attestation gating.
    def columns
      cols = [
        { name: 'bulk_actions',    label: '',                 sortable: false, type: :bulk_actions_column, header: :bulk_all },
        { name: 'legal_name',      label: 'Legal Name',       sortable: false, type: :string },
        { name: 'fein',            label: 'FEIN',             sortable: false, type: :string },
        { name: 'hbx_id',          label: 'HBX ID',           sortable: false, type: :integer },
        { name: 'broker',          label: 'Broker',           sortable: false, type: :string },
        { name: 'source_kind',     label: 'Source Kind',      sortable: false, type: :string, filter: { collection: SOURCE_KINDS, selected: 'all' } },
        { name: 'plan_year_state', label: 'Plan Year State',  sortable: false, type: :string },
        { name: 'effective_date',  label: 'Effective Date',   sortable: true,  type: :string },
        { name: 'invoiced?',       label: 'Invoiced?',        sortable: false, type: :string }
      ]
      cols << { name: 'attestation_status', label: 'Attestation Status', sortable: false, type: :string } if employer_attestation_is_enabled?
      cols << { name: 'actions', label: 'Actions', sortable: false, type: :string, width: '50px' }
      cols
    end

    # The collection is BenefitSponsorship.unscoped narrowed by the active filter
    # tab(s); created_at is its default order (no visible column is the active
    # sort) so the header carries no sort direction on load.
    def collection(attributes)
      benefit_sponsorships = BenefitSponsors::BenefitSponsorships::BenefitSponsorship.unscoped
      @attributes = attributes
      FILTER_MAPPINGS.each do |attribute, method|
        benefit_sponsorships = send(method, benefit_sponsorships) if attributes[attribute].present?
      end
      benefit_sponsorships
    end

    def default_order_column
      'created_at'
    end

    def global_search?
      true
    end

    # Applies the source_kind select filter. "all" means no column filter.
    def search_column(collection, column_name, value)
      return collection unless column_name.to_s == 'source_kind' && value.present? && value != 'all'

      collection.datatable_search_for_source_kind(value.to_sym)
    end

    def filters
      next_30_day = TimeKeeper.date_of_record.next_month.beginning_of_month
      next_60_day = next_30_day.next_month
      thirty = next_30_day.strftime('%m/%d/%Y')
      sixty = next_60_day.strftime('%m/%d/%Y')

      filters = {
        enrolling_renewing: [
          { scope: 'all', label: 'All' },
          { scope: 'benefit_application_renewal_pending', label: 'Application Pending' },
          { scope: 'benefit_application_enrolling_renewing_oe', label: 'Open Enrollment' }
        ],
        enrolling_initial: [
          { scope: 'all', label: 'All' },
          { scope: 'benefit_application_pending', label: 'Application Pending' },
          { scope: 'benefit_application_enrolling_initial_oe', label: 'Open Enrollment' },
          { scope: 'benefit_application_initial_binder_paid', label: 'Binder Paid' },
          { scope: 'benefit_application_initial_binder_pending', label: 'Binder Pending' }
        ],
        enrolled: [
          { scope: 'benefit_application_enrolled', label: 'All' },
          { scope: 'benefit_application_suspended', label: 'Suspended' }
        ],
        upcoming_dates: [
          { scope: thirty, label: thirty },
          { scope: sixty, label: sixty }
        ],
        enrolling: [
          { scope: 'benefit_application_enrolling', label: 'All' },
          { scope: 'benefit_application_enrolling_initial', label: 'Initial', subfilter: :enrolling_initial },
          { scope: 'benefit_application_enrolling_renewing', label: 'Renewing / Converting', subfilter: :enrolling_renewing },
          { scope: 'benefit_application_enrolling', label: 'Upcoming Dates', subfilter: :upcoming_dates }
        ],
        attestations: [
          { scope: 'employer_attestations', label: 'All' },
          { scope: 'submitted', label: 'Submitted' },
          { scope: 'pending', label: 'Pending' },
          { scope: 'approved', label: 'Approved' },
          { scope: 'denied', label: 'Denied' }
        ],
        employers: [
          { scope: 'all', label: 'All' },
          { scope: 'benefit_sponsorship_applicant', label: 'Applicants' },
          { scope: 'benefit_application_enrolling', label: 'Enrolling', subfilter: :enrolling },
          { scope: 'benefit_application_enrolled', label: 'Enrolled', subfilter: :enrolled }
        ],
        top_scope: :employers
      }
      filters[:employers] << { scope: 'employer_attestations', label: 'Employer Attestations', subfilter: :attestations } if employer_attestation_is_enabled?
      filters
    end

    # Every tab scope the filter bar can emit, collected into the attribute hash
    # #collection consumes. attestation_status rides along with the attestation
    # sub-tabs.
    def filter_scopes
      [:employers, :enrolling, :enrolling_initial, :enrolling_renewing, :enrolled,
       :upcoming_dates, :attestations, :employer_attestations, :attestation_status]
    end

    def date_filter
      nil
    end

    # The two bulk actions surfaced in the dropdown, in declared order. Each posts
    # the selected benefit-sponsorship ids to its existing endpoint.
    def bulk_actions
      [
        { label: 'Generate Invoice', url: Rails.application.routes.url_helpers.generate_invoice_exchanges_hbx_profiles_path, confirm: 'Generate Invoices?' },
        { label: 'Mark Binder Paid', url: Rails.application.routes.url_helpers.binder_paid_exchanges_hbx_profiles_path, confirm: 'Mark Binder Paid?' }
      ]
    end

    def buttons
      %w[csv excel]
    end

    def per_page_options
      [10, 25, 50, 100]
    end

    # The row-action dropdowns inject forms (e.g. Create Plan Year) whose native
    # selects must stay reachable, so page-global selectric is suppressed here.
    def disable_selectric?
      true
    end

    # The bulk-actions and actions columns are excluded from the export.
    def csv_headers
      data_columns.map { |col| col[:label] }
    end

    def csv_row(row)
      employer_profile = row.organization.employer_profile
      benefit_application = row.dt_display_benefit_application
      values = [
        row.organization.legal_name,
        row.organization.fein,
        row.organization.hbx_id,
        employer_profile&.active_broker_agency_legal_name,
        row.source_kind.to_s.humanize,
        (helpers.benefit_application_summarized_state(benefit_application) if benefit_application.present?),
        (benefit_application.effective_period.min&.strftime('%m/%d/%Y') if benefit_application.present?),
        employer_profile&.current_month_invoice.present?
      ]
      values << employer_profile&.attestation_status if employer_attestation_is_enabled?
      values
    end

    def row_partial
      'exchanges/hbx_profiles/datatables/employers_row'
    end

    # Dropdown link type for the per-row Generate Invoice action.
    def generate_invoice_link_type(employer_profile)
      employer_profile.current_month_invoice.present? ? 'disabled' : 'post_ajax'
    end

    # Dropdown link type for the per-row Force Publish action: shown only when a
    # draft application exists, its publish window is open, and the user is
    # allowed.
    def force_publish_link_type(benefit_sponsorship, allow)
      draft_application = latest_draft_benefit_application(benefit_sponsorship)
      draft_application.present? && business_policy_accepted?(draft_application) && allow ? 'ajax' : 'hide'
    end

    private

    def data_columns
      columns.reject { |col| %w[bulk_actions actions].include?(col[:name]) }
    end

    def latest_draft_benefit_application(benefit_sponsorship)
      draft_apps = benefit_sponsorship.benefit_applications.draft_state
      draft_apps.present? ? draft_apps.last : ''
    end

    def business_policy_accepted?(draft_application)
      TimeKeeper.date_of_record > draft_application.last_day_to_publish && TimeKeeper.date_of_record < draft_application.start_on
    end

    def helpers
      ApplicationController.helpers
    end

    def call_safe_method(object, method)
      return object unless method.present? && ALLOWED_METHODS.include?(method)

      if object.respond_to?(method)
        object.public_send(method)
      else
        Rails.logger.warn("Attempted to call method that does not respond: #{method}")
        object
      end
    end

    def filter_by_employers(benefit_sponsorships)
      return benefit_sponsorships unless @attributes[:employers].present? && !['all'].include?(@attributes[:employers])

      call_safe_method(benefit_sponsorships, @attributes[:employers])
    end

    def filter_by_enrolling(benefit_sponsorships)
      return benefit_sponsorships unless @attributes[:enrolling_status].present?

      enrolling_scope_map = {
        'active' => :active_enrolling,
        'renewing' => :renewing_enrolling,
        'terminated' => :terminated_enrolling
      }

      scope = enrolling_scope_map[@attributes[:enrolling_status]]
      if scope && benefit_sponsorships.respond_to?(scope)
        benefit_sponsorships.send(scope)
      else
        Rails.logger.warn("Invalid enrolling status: #{@attributes[:enrolling_status]}")
        benefit_sponsorships
      end
    end

    def filter_by_enrolled(benefit_sponsorships)
      @attributes[:enrolled].present? ? call_safe_method(benefit_sponsorships, @attributes[:enrolled]) : benefit_sponsorships
    end

    def filter_by_employer_attestations(benefit_sponsorships)
      return benefit_sponsorships unless @attributes[:employer_attestations].present?

      benefit_sponsorships = call_safe_method(benefit_sponsorships, @attributes[:employer_attestations])

      status_scope_map = {
        'submitted' => :submitted,
        'pending' => :pending,
        'approved' => :approved,
        'denied' => :denied
      }

      if @attributes[:attestation_status].present?
        scope = status_scope_map[@attributes[:attestation_status]]
        benefit_sponsorships = benefit_sponsorships.send(scope) if scope && benefit_sponsorships.respond_to?(scope)
      end

      benefit_sponsorships
    end

    def filter_by_upcoming_dates(benefit_sponsorships)
      return benefit_sponsorships unless @attributes[:upcoming_dates].present?

      date = parse_date(@attributes[:upcoming_dates])
      date ? benefit_sponsorships.effective_date_begin_on(date) : benefit_sponsorships
    end

    def filter_by_attestations(benefit_sponsorships)
      return benefit_sponsorships unless @attributes[:attestations].present? && @attributes[:attestations] != 'employer_attestations'

      benefit_sponsorships.attestations_by_kind(@attributes[:attestations])
    end

    def parse_date(date_str)
      Date.strptime(date_str, '%m/%d/%Y')
    rescue StandardError => e
      Rails.logger.warn("Date parsing error: #{e.message}")
      nil
    end
  end
end
