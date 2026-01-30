# frozen_string_literal: true

module Mongoid
  module RecursiveEmbeddedValidation
    extend ActiveSupport::Concern

    included do
      validate :validate_embedded_documents_recursively
    end

    private

    def validate_embedded_documents_recursively
      _validate_embedded(self)
    end

    def _validate_embedded(document, path = [])
      # 1. Get only downward associations (avoiding the 'EmbeddedIn' crash)
      associations = document.class.reflect_on_all_associations(:embeds_one, :embeds_many)

      associations.each do |relation|
        relation_name = relation.name

        # Debugging: Uncomment to see what's happening
        # puts "Checking relation: #{relation_name} on #{document.class}"

        # 2. Retrieve the documents.
        #    Use 'send' to get the proxy, then Array.wrap to handle one/many/nil safely.
        raw_value = document.send(relation_name)
        children  = Array.wrap(raw_value).compact

        # Debugging: Uncomment to see if children are found
        # puts "  -> Found #{children.size} children"

        children.each_with_index do |child, idx|
          # 3. Skip records that are being deleted (standard Rails behavior)
          next if child.marked_for_destruction?

          # 4. ALWAYS manually check valid?
          #    This forces the validation rules to run on the child
          unless child.valid?
            child.errors.each do |error|
              attribute = error.attribute
              message   = error.message

              # Build the full error path (e.g. benefit_groups.0.relationship_benefits.0.premium_pct)
              full_path = (path + [relation_name, idx, attribute]).join(".")

              # Add the error to the top-level parent
              errors.add(full_path, message)
            end
          end

          # 5. Recurse deeper (e.g. check relationship_benefits inside benefit_groups)
          _validate_embedded(child, path + [relation_name, idx])
        end
      end
    end
  end
end