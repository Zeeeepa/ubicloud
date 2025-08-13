# frozen_string_literal: true

require_relative "../model"

class StaticApp < Sequel::Model
  one_to_one :strand, key: :id
  many_to_one :project

  plugin ResourceMethods
  plugin SemaphoreMethods, :deploy, :destroy

  def domain_prefix
    "#{name}-#{project.ubid[-5..]}"
  end

  def domain
    "https://#{domain_prefix}.ubicloud.app"
  end

  def run_kubectl(cmd)
    kubeconfig_path = "var/static-app-prod-kubeconfig.yaml"
    cmd = [
      "kubectl",
      "--kubeconfig", kubeconfig_path,
      "-n", project.ubid,
      *cmd
    ]

    stdout_str, stderr_str, status = Open3.capture3(*cmd)

    unless status.success?
      fail "kubectl error: #{stderr_str.strip}"
    end

    stdout_str
  end

  def deployment_status
    data = JSON.parse(run_kubectl(["get", "deployment", ubid, "-o", "json"]))

    updated = data.dig("status", "updatedReplicas").to_i
    replicas = data.dig("status", "replicas").to_i
    available = data.dig("status", "availableReplicas").to_i

    if updated == replicas && replicas == available
      "Ready"
    else
      "Deploying"
    end
  rescue
    "Creating"
  end

  def build_logs
    pod_name = run_kubectl([
      "get", "pods",
      "--selector=app=#{ubid}",
      "--sort-by=.metadata.creationTimestamp",
      "-o", "jsonpath={.items[-1:].metadata.name}"
    ])
    run_kubectl(["logs", pod_name, "-c", "build-site", "--timestamps=true"])
  rescue
    "No build logs available"
  end

  def delete_resources
    run_kubectl(["delete", "deployment", ubid])
    run_kubectl(["delete", "ingress", ubid])
    run_kubectl(["delete", "ingress", "#{ubid}-custom-domain", "--ignore-not-found"])
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
