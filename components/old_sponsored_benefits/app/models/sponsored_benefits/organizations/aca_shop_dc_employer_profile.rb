module SponsoredBenefits
  module Organizations
    class AcaShopDcEmployerProfile < Profile

      field :profile_source, type: String, default: "broker_quote"
      field :contact_method, type: String, default: "Only Electronic communications"

    end
  end
end
