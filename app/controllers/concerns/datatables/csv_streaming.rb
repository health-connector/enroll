# frozen_string_literal: true

module Datatables
  # Streams a full filtered datatable export as CSV without building the whole
  # document in memory. Deliberately uncapped: a future row cap belongs here as
  # a guard clause once production export sizes are known.
  module CsvStreaming
    extend ActiveSupport::Concern

    private

    def stream_datatable_csv(filename:, headers:, rows:)
      response.headers['Content-Type'] = 'text/csv; charset=utf-8'
      response.headers['Content-Disposition'] = %(attachment; filename="#{filename}")
      # Rack::ETag buffers bodies it can digest; a Last-Modified header opts out
      # so the enumerator actually streams.
      response.headers['Last-Modified'] = Time.now.httpdate
      self.response_body = Enumerator.new do |yielder|
        yielder << CSV.generate_line(headers)
        rows.each { |row| yielder << CSV.generate_line(row) }
      end
    end

    # Query wrappers expose skip/limit but not each; skip(0) materializes the
    # underlying Mongoid criteria, which iterates with a DB cursor.
    def datatable_csv_rows(table, scoped)
      criteria = scoped.respond_to?(:each) ? scoped : scoped.skip(0)
      criteria.lazy.map { |record| table.csv_row(record) }
    end
  end
end
