# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:static_app) do
      column :id, :uuid, primary_key: true
      foreign_key :project_id, :project, type: :uuid, null: false
      String :repository, null: false
      String :branch, null: false
      String :build_command, null: false
      String :output_dir, null: false
    end
  end
end
