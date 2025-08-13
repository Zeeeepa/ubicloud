# frozen_string_literal: true
require "open3"

class Prog::StaticAppNexus < Prog::Base
  subject_is :static_app

  def self.assemble(project_id, repo, branch, build_command, output_dir)
    app = StaticApp.create(
      project_id: project_id,
      repository: repo,
      branch: branch,
      build_command: build_command,
      output_dir: output_dir
    )

    Strand.create_with_id(app.id, prog: "StaticAppNexus", label: "wait")
  end

  label def wait
    when_deploy_set? do
      register_deadline(:wait, 5 * 60)
      hop_deploy
    end

    nap 10
  end

  label def deploy
    do_deploy
    hop_wait
  end

  def do_deploy
    decr_deploy

    kubeconfig_path = "/home/hadi/static-app/static-app-prod-kubeconfig.yaml"
    customer_project_ubid = static_app.project.ubid
    unique_name = static_app.ubid
    domain_prefix = unique_name

    yaml_data = <<~YAML
apiVersion: v1
kind: Namespace
metadata:
  name: #{customer_project_ubid}
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: #{unique_name}
  namespace: #{customer_project_ubid}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: #{unique_name}
  template:
    metadata:
      labels:
        app: #{unique_name}
    spec:
      volumes:
        - name: site-content
          emptyDir: {}
      initContainers:
        - name: build-site
          image: ubuntu:24.04
          command:
            - sh
            - -c
            - |
              apt-get update && \
              apt-get install -y git curl build-essential && \
              rm -rf /repo && \
              git clone #{static_app.repository} /repo && \
              cd /repo && \
              git checkout #{static_app.branch} && \
              #{static_app.build_command}
              cp -r #{static_app.output_dir}/* /site
          volumeMounts:
            - name: site-content
              mountPath: /site
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
          volumeMounts:
            - name: site-content
              mountPath: /usr/share/nginx/html
---
apiVersion: v1
kind: Service
metadata:
 name: #{unique_name}
 namespace: #{customer_project_ubid}
spec:
 selector:
   app: #{unique_name}
 ports:
 - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
 name: #{unique_name}
 namespace: #{customer_project_ubid}
 annotations:
   cert-manager.io/cluster-issuer: letsencrypt
spec:
 ingressClassName: nginx
 tls:
 - hosts:
   - #{domain_prefix}.ubicloud.app
   secretName: #{unique_name}-ingress-tls
 rules:
 - host: #{domain_prefix}.ubicloud.app
   http:
     paths:
     - path: /
       pathType: Prefix
       backend:
         service:
           name: #{unique_name}
           port:
             number: 80
    YAML

    Open3.popen3(
      "kubectl",
      "--kubeconfig", kubeconfig_path,
      "apply", "-f", "-"
    ) do |stdin, stdout, stderr, wait_thr|
      stdin.write(yaml_data)
      stdin.close

      puts "STDOUT:\n#{stdout.read}"
      puts "STDERR:\n#{stderr.read}"

      unless wait_thr.value.success?
        abort "kubectl failed!"
      end
    end
  end

end
