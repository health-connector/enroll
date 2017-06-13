class SicRateReference
	include Mongoid::Document

	field :sic, type: String
	field :hios_id, type: String
	field :cost_ratio, type: Float
	field :applicable_year, type: Integer
	

	validates :sic, :hios_id, :cost_ratio, :applicable_year, presence: true
	validates :sic, uniqueness: { scope: :hios_id }
	

end
