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

        r.post true do
          no_authorization_needed
          handle_validation_failure("page/create")

          repository = typecast_params.nonempty_str!("repository")
          branch = typecast_params.nonempty_str!("branch")

          if @project.static_apps_dataset.first(repository:, branch:)
            fail CloverError.new(400, "InvalidRequest", "You can't create a page with the same repository and branch again")
          end

          page = Prog::StaticAppNexus.assemble(
            @project.id,
            typecast_params.nonempty_str!("name"),
            repository,
            branch,
            typecast_params.nonempty_str!("build_command"),
            typecast_params.nonempty_str!("src_dir"),
            typecast_params.nonempty_str!("output_dir"),
            custom_domain: typecast_params.str("custom_domain")
          ).subject
          page.incr_deploy

          flash["notice"] = "Page '#{page.name}' created successfully"
          r.redirect "#{@project.path}/page/#{@installation.ubid}/app/#{page.ubid}"
        end

        r.get "create" do
          view "page/create"
        end

        r.on "app" do
          r.on :ubid_uuid do |id|
            next unless (@static_app = StaticApp[id:])

            r.get true do
              view "page/show"
            end

            r.post "deploy" do
              @static_app.incr_deploy
              flash["notice"] = "Page '#{@static_app.name}' deployment triggered successfully"
              r.redirect "#{@project.path}/page/#{@installation.ubid}/app/#{@static_app.ubid}"
            end

            r.delete true do |id|
              @static_app.incr_destroy
              flash["notice"] = "Page '#{@static_app.name}' deletion triggered successfully"
              204
            end
          end
        end
      end
    end
  end
end
