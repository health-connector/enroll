# frozen_string_literal: true

FactoryBot.define do
  factory(:generative_email, {class: Email}) do
    kind do
      Email::KINDS[Random.rand(2)]
    end
    address { Forgery('email').address }
  end

  factory(:generative_phone, {class: Phone}) do
    kind do
      Phone::KINDS[Random.rand(5)]
    end
    full_phone_number { Forgery('address').phone }
  end

  factory(:generative_address, {class: Address}) do
    kind do
      Address::KINDS[Random.rand(3)]
    end
    address_1 { Forgery('address').street_address }
    address_2 do
      Forgery('address').street_address if Forgery('basic').boolean
    end
    state { Forgery('address').state_abbrev }
    zip { Forgery('address').zip }
    city { Forgery('address').city }
  end
end
