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

        r.post do
          no_authorization_needed

          page = Prog::StaticAppNexus.assemble(
            @project.id,
            typecast_params.nonempty_str!("name"),
            typecast_params.nonempty_str!("repository"),
            typecast_params.nonempty_str!("branch"),
            typecast_params.nonempty_str!("build_command"),
            typecast_params.nonempty_str!("src_dir"),
            typecast_params.nonempty_str!("output_dir")
          ).subject

          flash["notice"] = "Page '#{page.name}' created successfully"
          r.redirect "#{@project.path}/page/#{@installation.ubid}"
        end

        r.get "create" do
          @repositories = Github.installation_client(@installation.installation_id).list_app_installation_repositories.repositories.map { [it.full_name, it.full_name] }
          view "page/create"
        end
      end
    end
  end
end
