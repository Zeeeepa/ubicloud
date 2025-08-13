# frozen_string_literal: true

require_relative "../model"

class StaticApp < Sequel::Model
  one_to_one :strand, key: :id
  many_to_one :project

  plugin ResourceMethods
  plugin SemaphoreMethods, :deploy

  def url
    "https://#{name}-#{project.ubid[0..5]}.ubicloud.app"
  end
end

# Table: static_app
# Columns:
#  id            | uuid | PRIMARY KEY
#  project_id    | uuid | NOT NULL
#  repository    | text | NOT NULL
#  branch        | text | NOT NULL
#  build_command | text | NOT NULL
#  output_dir    | text | NOT NULL
#  name          | text | NOT NULL
#  src_dir       | text | NOT NULL
# Indexes:
#  static_app_pkey | PRIMARY KEY btree (id)
# Foreign key constraints:
#  static_app_project_id_fkey | (project_id) REFERENCES project(id)
