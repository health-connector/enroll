module ComposedModel

  def self.included(base)
    base.class_eval do
      extend ComposedModel::ComposedModelClassMethods
    end
  end

  def validate_collection_and_propagate_errors(collection_name, objs)
    objs.each_with_index do |obj, idx|
      obj.valid?
      obj.errors.each do |attr, err|
        errors.add(validate_collection_error_key_name(collection_name, idx, attr), err)
      end
    end
  end

  def validate_collection_error_key_name(collection_name, idx, property)
    "#{collection_name}_attributes[#{idx}][#{property}]"
  end

  module ComposedModelClassMethods
    def composed_of_many(name, klass_name, do_validation_on_collection = false)
      define_method("#{name}=") do |vals|
        instance_variable_set("@#{name}", []) unless instance_variable_defined?("@#{name}")
        instance_variable_set("@#{name}", vals) unless vals.nil?
        instance_variable_get("@#{name}")
        end

      define_method(name) do
        instance_variable_set("@#{name}", []) unless instance_variable_defined?("@#{name}")
        instance_variable_get("@#{name}")
      end

      define_method("#{name}_attributes=") do |vals|
        if vals.nil?
          instance_variable_set("@#{name}", [])
          return []
        end

        klass = Object.const_get(klass_name)
        instance_variable_set("@#{name}", vals.map { |v_attrs| klass.new(v_attrs) })
        send("#{name}_attributes")
      end

      return unless do_validation_on_collection

      define_method("#{name}_validation_steps") do
        objs_to_validate = send(name)
        validate_collection_and_propagate_errors(name.to_s, objs_to_validate)
      end

      validate "#{name}_validation_steps"
    end
  end
end
