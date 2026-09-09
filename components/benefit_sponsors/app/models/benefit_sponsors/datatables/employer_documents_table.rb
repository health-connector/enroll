# frozen_string_literal: true

module BenefitSponsors
  module Datatables
    # Table definition for the employer portal's Documents tab, listing the
    # profile's employer attestation documents. Implements the table contract
    # documented in ::Datatables::FragmentRendering, except the CSV methods: the
    # tab renders no export button.
    class EmployerDocumentsTable
      def initialize(employer_profile)
        @employer_profile = employer_profile
      end

      def param_key
        'employer_documents'
      end

      # The first column's name is the literal "Doc Status" (a space and all),
      # which reaches the th and td class attributes as `col-Doc Status`. It is
      # also the default-ordered column, so it carries the sort indicator and its
      # cells the sort shading.
      def columns
        [
          { name: 'Doc Status', label: 'Doc Status',   sortable: false, type: :string, ordered: true },
          { name: 'name',       label: 'Doc Name',     sortable: false, type: :string },
          { name: 'type',       label: 'Doc Type',     sortable: false, type: :string },
          { name: 'size',       label: 'Size',         sortable: false, type: :string },
          { name: 'date',       label: 'Submitted At', sortable: false, type: :string },
          { name: 'actions',    label: 'Actions',      sortable: false, type: :string, width: '50px' }
        ]
      end

      def collection(_attributes)
        attestation = @employer_profile.employer_attestation
        return EmployerAttestationDocument.none if attestation.blank?

        attestation.employer_attestation_documents
      end

      # No search box renders on this tab.
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

      def default_order_column
        'Doc Status'
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

      def per_page_options
        [10, 25, 50, 100]
      end

      def layout
        ::Datatables::Layouts::STANDARD
      end

      def row_partial
        'benefit_sponsors/profiles/employers/employer_profiles/datatables/employer_documents_row'
      end

      # Delete is offered only while the attestation is still editable and the
      # document itself is submitted.
      def delete_link_type(document)
        @employer_profile.employer_attestation.editable? && document.submitted? ? 'delete ajax with confirm' : 'disabled'
      end

      def employer_profile_id
        @employer_profile.id
      end
    end
  end
end
