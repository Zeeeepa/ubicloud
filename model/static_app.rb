# frozen_string_literal: true

require_relative "../model"

class StaticApp < Sequel::Model
  one_to_one :strand, key: :id
  many_to_one :project

  plugin ResourceMethods
  plugin SemaphoreMethods, :deploy
end
