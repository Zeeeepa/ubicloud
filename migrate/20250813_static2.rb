# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:static_app) do
      add_column :name, String, collate: '"C"', null: false
      add_column :src_dir, String, collate: '"C"', null: false
    end
  end
end
