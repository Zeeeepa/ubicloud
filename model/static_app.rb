# frozen_string_literal: true

require_relative "../model"

class StaticApp < Sequel::Model
  one_to_one :strand, key: :id
  many_to_one :project

  plugin ResourceMethods
  plugin SemaphoreMethods, :deploy, :add_custom_domain

  def domain_prefix
    "#{name}-#{project.ubid[-5..]}"
  end

  def domain
    "https://#{domain_prefix}.ubicloud.app"
  end

  def deployment_status
    kubeconfig_path = "var/static-app-prod-kubeconfig.yaml"
    cmd = [
      "kubectl",
      "--kubeconfig", kubeconfig_path,
      "-n", project.ubid,
      "get", "deployment", ubid,
      "-o", "json"
    ]

    stdout_str, stderr_str, status = Open3.capture3(*cmd)

    unless status.success?
      warn "kubectl error: #{stderr_str.strip}"
      abort "Failed to fetch deployment status for #{ubid} in #{project.ubid}"
    end

    data = JSON.parse(stdout_str)

    updated = data.dig("status", "updatedReplicas").to_i
    replicas = data.dig("status", "replicas").to_i
    available = data.dig("status", "availableReplicas").to_i

    if updated == replicas && replicas == available
      "Ready"
    else
      "Updating"
    end
  end

  def build_logs
    kubeconfig_path = "var/static-app-prod-kubeconfig.yaml"
    cmd = [
      "kubectl",
      "--kubeconfig", kubeconfig_path,
      "-n", project.ubid,
      "logs", "deployment/#{ubid}",
      "-c", "build-site"
    ]

    stdout_str, stderr_str, status = Open3.capture3(*cmd)
    unless status.success?
      warn "kubectl error: #{stderr_str.strip}"
      abort "Failed to fetch deployment status for #{ubid} in #{project.ubid}"
    end

    stdout_str
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
#  custom_domain | text |
# Indexes:
#  static_app_pkey | PRIMARY KEY btree (id)
# Foreign key constraints:
#  static_app_project_id_fkey | (project_id) REFERENCES project(id)
