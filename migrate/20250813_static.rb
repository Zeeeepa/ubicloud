# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:static_app) do
      primary_key :id, type: :uuid
      foreign_key :project_id, :project, type: :uuid, null: false
      String :repository, null: false
      String :branch, null: false
      String :build_command, null: false
      String :output_dir, null: false
    end
  end
end
