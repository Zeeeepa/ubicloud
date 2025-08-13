# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:static_app) do
      add_column :custom_domain, String, collate: '"C"', null: true
    end
  end
end
