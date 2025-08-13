# frozen_string_literal: true

require_relative "../model"

class StaticApp < Sequel::Model
  many_to_one :project

  plugin ResourceMethods
  plugin SemaphoreMethods, :deploy
end
