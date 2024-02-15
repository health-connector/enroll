# frozen_string_literal: true

class Book
  include Mongoid::Document
  include Mongoid::Userstamp

  mongoid_userstamp user_model: 'User'

  field :name
end