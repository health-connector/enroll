module BenefitMarkets
  class Products::PremiumTuple
    include Mongoid::Document
    include Mongoid::Timestamps

    # touch: false keeps bulk rate loads from touching the parent once per
    # embedded child (quadratic on Mongoid 8+ where touch defaults to true)
    embedded_in :premium_table,
                class_name: "BenefitMarkets::Products::PremiumTable",
                touch: false

    field :age,   type: Integer
    field :cost,  type: Float

    validates_presence_of :age, :cost

    default_scope   ->{ order(:"age".asc) }


    def comparable_attrs
      [:age, :cost]
    end

    # Define Comparable operator
    # If instance attributes are the same, compare PremiumTuples
    def <=>(other)
      if comparable_attrs.all? { |attr| send(attr) == other.send(attr) }
        0
      else
        other.updated_at.blank? || (updated_at < other.updated_at) ? -1 : 1
      end
    end
  end
end
