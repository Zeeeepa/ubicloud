# frozen_string_literal: true

class Clover
  hash_branch(:project_prefix, "page") do |r|
    r.web do
      # authorize("Project:github", @project.id)

      r.get true do
        if (installation = @project.github_installations_dataset.first)
          r.redirect "#{@project.path}/page/#{installation.ubid}"
        end
        view "page/index"
      end

      r.get "create" do
        handle_validation_failure("github/index")
        unless @project.has_valid_payment_method?
          raise_web_error("Project doesn't have valid billing information")
        end
        session[:github_installation_project_id] = @project.id

        r.redirect "https://github.com/apps/#{Config.github_app_name}/installations/new", 302
      end

      r.on :ubid_uuid do |id|
        next unless (@installation = GithubInstallation[id:, project_id: @project.id])

        r.get true do
          view "page/page"
        end
      end
    end
  end
end
