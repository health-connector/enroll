# frozen_string_literal: true

module ModelEvents
  # Helper module to safely check local/class variables without using eval() or instance_eval()
  module DefineVariableHelper
    # Safely checks if a local/class variable exists and returns its value
    # Imitates the behavior of instance_eval() without using eval()
    # @param variable_name [String] name of the variable to check
    # @return [Object, nil] the variable's value if it exists and is truthy, nil otherwise
    def check_local_variable(expression, context = binding)
      var_name = expression.to_sym
      return context.local_variable_get(var_name) if context.local_variable_defined?(var_name)

      var_name = "@#{expression}".to_sym
      return instance_variable_get(var_name) if instance_variable_defined?(var_name)

      return send(expression) if respond_to?(expression)
    end
  end
end


