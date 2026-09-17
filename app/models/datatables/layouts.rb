# frozen_string_literal: true

module Datatables
  # Grid arrangements for the chrome around a table, consumed by
  # app/views/datatables/_table.html.erb. Each layout is an ordered list of
  # rows; each row an ordered list of cells carrying the bootstrap column
  # classes and the features rendered inside them.
  #
  # Recognized features: :buttons, :search, :table, :processing, :info,
  # :length, :pagination. A cell with no features renders an empty column
  # (some arrangements use one for spacing).
  module Layouts
    # The arrangement every table uses unless it declares otherwise.
    STANDARD = [
      [
        { class: 'col-sm-7 col-md-7', features: [:buttons] },
        { class: 'col-sm-5 col-md-5', features: [:search] }
      ],
      [
        { class: 'col-sm-12 col-md-12', features: [] }
      ],
      [
        { class: 'col-sm-12 col-md-12', features: [:table, :processing] }
      ],
      [
        { class: 'col-sm-11 col-md-11', features: [:info] },
        { class: 'col-sm-1 col-md-1', features: [:length] }
      ],
      [
        { class: 'col-sm-12 col-md-12', features: [:pagination] }
      ]
    ].freeze

    # Arrangement for tables whose only header control is the search box: no
    # button group, a narrower table column, and the page-length menu beside the
    # info line.
    SEARCH_ONLY = [
      [
        { class: 'col-sm-5', features: [] },
        { class: 'col-sm-5', features: [:search] }
      ],
      [
        { class: 'col-sm-10', features: [:table, :processing] }
      ],
      [
        { class: 'col-sm-9', features: [:info] },
        { class: 'col-sm-3', features: [:length] }
      ],
      [
        { class: 'col-sm-10', features: [:pagination] }
      ]
    ].freeze
  end
end
