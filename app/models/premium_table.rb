class PremiumTable
  include Mongoid::Document
  include Config::AcaModelConcern

  # touch defaults to true on embedded_in since Mongoid 8; bulk premium table
  # loads (rake xml:rates) touch the parent once per child, making the import
  # quadratic in the number of premium tables
  embedded_in :plan, touch: false

  field :age, type: Integer
  field :start_on, type: Date
  field :end_on, type: Date
  field :cost, type: Float
  field :rating_area, type: String

  validates_presence_of :age, :start_on, :end_on, :cost

  validates_inclusion_of :rating_area, :in => market_rating_areas, :allow_nil => true

  scope :by_date, ->(date){ where(:start_on.lte => date, :end_on.gte => date) }

end
