class SicCode
  include Mongoid::Document
  field :code, type: String
  field :industry_group, type: String
  field :major_group, type: String
  field :division, type: String

  validates_presence_of :code, :industry_group, :major_group, :division
end
