# frozen_string_literal: true

module Datatables
  # View helpers for the Pagy + Stimulus datatable partials.
  module TableHelper
    DATATABLE_PAGE_BUTTONS = 7

    # Zero-based page numbers (and :ellipsis markers) replicating the
    # jQuery DataTables 'simple_numbers' pager layout, which differs from
    # Pagy#series in how it pins the first/last pages - the legacy pager markup
    # is the parity contract for the migration, so its algorithm is reproduced here.
    def datatable_page_series(pagy)
      # An empty result set renders no numbered page buttons (only the disabled
      # Previous/Next), matching the legacy DataTables pager at zero records.
      return [] if pagy.count.zero?

      page = pagy.page - 1
      pages = pagy.last
      buttons = DATATABLE_PAGE_BUTTONS
      half = buttons / 2

      if pages <= buttons
        (0...pages).to_a
      elsif page <= half
        (0...(buttons - 2)).to_a + [:ellipsis, pages - 1]
      elsif page >= pages - 1 - half
        [0, :ellipsis] + ((pages - (buttons - 2))...pages).to_a
      else
        [0, :ellipsis] + ((page - half + 2)...(page + half - 1)).to_a + [:ellipsis, pages - 1]
      end
    end
  end
end
