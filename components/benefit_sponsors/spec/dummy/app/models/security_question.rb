class SecurityQuestion
  include Mongoid::Document

  field :title, type: String
  field :visible, type: Mongoid::Boolean, default: true
end
