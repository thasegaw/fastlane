module FastlaneCore
  # Represents an Xcode project
  class Project
    class << self
      # Project discovery
      def detect_projects(config)
        if config[:workspace].to_s.length > 0 and config[:project].to_s.length > 0
          UI.user_error!("You can only pass either a workspace or a project path, not both")
        end

        return if config[:project].to_s.length > 0

        if config[:workspace].to_s.length == 0
          workspace = Dir["./*.xcworkspace"]
          if workspace.count > 1
            puts "Select Workspace: "
            config[:workspace] = choose(*workspace)
          elsif !workspace.first.nil?
            config[:workspace] = workspace.first
          end
        end

        return if config[:workspace].to_s.length > 0

        if config[:workspace].to_s.length == 0 and config[:project].to_s.length == 0
          project = Dir["./*.xcodeproj"]
          if project.count > 1
            puts "Select Project: "
            config[:project] = choose(*project)
          elsif !project.first.nil?
            config[:project] = project.first
          end
        end

        if config[:workspace].nil? and config[:project].nil?
          select_project(config)
        end
      end

      def select_project(config)
        loop do
          path = UI.input("Couldn't automatically detect the project file, please provide a path: ")
          if File.directory? path
            if path.end_with? ".xcworkspace"
              config[:workspace] = path
              break
            elsif path.end_with? ".xcodeproj"
              config[:project] = path
              break
            else
              UI.error("Path must end with either .xcworkspace or .xcodeproj")
            end
          else
            UI.error("Couldn't find project at path '#{File.expand_path(path)}'")
          end
        end
      end
    end

    # Path to the project/workspace
    attr_accessor :path

    # Is this project a workspace?
    attr_accessor :is_workspace

    # The config object containing the scheme, configuration, etc.
    attr_accessor :options

    attr_accessor :xcodebuild

    def initialize(options, xcodebuild_list_silent: false, xcodebuild_suppress_stderr: false)
      self.options = options
      self.xcodebuild = FastlaneCore::Xcodebuild.new(
        options,
        xcodebuild_list_silent: xcodebuild_list_silent,
        xcodebuild_suppress_stderr: xcodebuild_suppress_stderr
      )
      self.path = File.expand_path(options[:workspace] || options[:project])
      self.is_workspace = (options[:workspace].to_s.length > 0)

      if !path or !File.directory?(path)
        UI.user_error!("Could not find project at path '#{path}'")
      end
    end

    def workspace?
      self.is_workspace
    end

    def project_name
      if is_workspace
        return File.basename(options[:workspace], ".xcworkspace")
      else
        return File.basename(options[:project], ".xcodeproj")
      end
    end

    # Get all available schemes in an array
    def schemes
      parsed_info.schemes
    end

    def targets
      parsed_info.targets
    end

    # Let the user select a scheme
    # Use a scheme containing the preferred_to_include string when multiple schemes were found
    def select_scheme(preferred_to_include: nil)
      if options[:scheme].to_s.length > 0
        # Verify the scheme is available
        unless schemes.include?(options[:scheme].to_s)
          UI.error("Couldn't find specified scheme '#{options[:scheme]}'.")
          options[:scheme] = nil
        end
      end

      return if options[:scheme].to_s.length > 0

      if schemes.count == 1
        options[:scheme] = schemes.last
      elsif schemes.count > 1
        preferred = nil
        if preferred_to_include
          preferred = schemes.find_all { |a| a.downcase.include?(preferred_to_include.downcase) }
        end

        if preferred_to_include and preferred.count == 1
          options[:scheme] = preferred.last
        elsif automated_scheme_selection? && schemes.include?(project_name)
          UI.important("Using scheme matching project name (#{project_name}).")
          options[:scheme] = project_name
        elsif Helper.is_ci?
          UI.error("Multiple schemes found but you haven't specified one.")
          UI.error("Since this is a CI, please pass one using the `scheme` option")
          show_scheme_shared_information
          UI.user_error!("Multiple schemes found")
        else
          puts "Select Scheme: "
          options[:scheme] = choose(*schemes)
        end
      else
        show_scheme_shared_information

        UI.user_error!("No Schemes found")
      end
    end

    def show_scheme_shared_information
      UI.error("Couldn't find any schemes in this project, make sure that the scheme is shared if you are using a workspace")
      UI.error("Open Xcode, click on `Manage Schemes` and check the `Shared` box for the schemes you want to use")
      UI.error("Afterwards make sure to commit the changes into version control")
    end

    # Get all available configurations in an array
    def configurations
      parsed_info.configurations
    end

    # Returns bundle_id and sets the scheme for xcrun
    def default_app_identifier
      default_build_settings(key: "PRODUCT_BUNDLE_IDENTIFIER")
    end

    # Returns app name and sets the scheme for xcrun
    def default_app_name
      if is_workspace
        return default_build_settings(key: "PRODUCT_NAME")
      else
        return app_name
      end
    end

    def app_name
      # WRAPPER_NAME: Example.app
      # WRAPPER_SUFFIX: .app
      name = build_settings(key: "WRAPPER_NAME")

      return name.gsub(build_settings(key: "WRAPPER_SUFFIX"), "") if name
      return "App" # default value
    end

    def dynamic_library?
      (build_settings(key: "PRODUCT_TYPE") == "com.apple.product-type.library.dynamic")
    end

    def static_library?
      (build_settings(key: "PRODUCT_TYPE") == "com.apple.product-type.library.static")
    end

    def library?
      (static_library? || dynamic_library?)
    end

    def framework?
      (build_settings(key: "PRODUCT_TYPE") == "com.apple.product-type.framework")
    end

    def application?(target: nil)
      (build_settings(key: "PRODUCT_TYPE", target: target) == "com.apple.product-type.application")
    end

    def test?(target: nil)
      type = build_settings(key: "PRODUCT_TYPE", target: target)
      (type == "com.apple.product-type.bundle.unit-test" || type == "com.apple.product-type.bundle.ui-testing")
    end

    def ios_library?
      ((static_library? or dynamic_library?) && build_settings(key: "PLATFORM_NAME") == "iphoneos")
    end

    def ios_tvos_app?
      (ios? || tvos?)
    end

    def ios_framework?
      (framework? && build_settings(key: "PLATFORM_NAME") == "iphoneos")
    end

    def ios_app?
      (application? && build_settings(key: "PLATFORM_NAME") == "iphoneos")
    end

    def produces_archive?
      !(framework? || static_library? || dynamic_library?)
    end

    def mac_app?
      (application? && build_settings(key: "PLATFORM_NAME") == "macosx")
    end

    def mac_library?
      ((dynamic_library? or static_library?) && build_settings(key: "PLATFORM_NAME") == "macosx")
    end

    def mac_framework?
      (framework? && build_settings(key: "PLATFORM_NAME") == "macosx")
    end

    def command_line_tool?
      (build_settings(key: "PRODUCT_TYPE") == "com.apple.product-type.tool")
    end

    def mac?
      supported_platforms.include?(:macOS)
    end

    def tvos?
      supported_platforms.include?(:tvOS)
    end

    def ios?
      supported_platforms.include?(:iOS)
    end

    def supported_platforms
      supported_platforms = build_settings(key: "SUPPORTED_PLATFORMS")
      if supported_platforms.nil?
        UI.important("Could not read the \"SUPPORTED_PLATFORMS\" build setting, assuming that the project supports iOS only.")
        return [:iOS]
      end
      supported_platforms.split.map do |platform|
        case platform
        when "macosx" then :macOS
        when "iphonesimulator", "iphoneos" then :iOS
        when "watchsimulator", "watchos" then :watchOS
        when "appletvsimulator", "appletvos" then :tvOS
        end
      end.uniq.compact
    end

    #####################################################
    # @!group Raw Access
    #####################################################

    # Get the build settings for our project
    # e.g. to properly get the DerivedData folder
    # @param [String] The key of which we want the value for (e.g. "PRODUCT_NAME")
    def build_settings(key: nil, optional: true, target: nil)
      target ||= targets.first

      unless @build_settings
        @build_settings = self.xcodebuild.showbuildsettings
      end

      begin
        result = @build_settings.targets[target].split("\n").find do |c|
          sp = c.split(" = ")
          next if sp.length == 0
          sp.first.strip == key
        end
        return result.split(" = ").last
      rescue => ex
        return nil if optional # an optional value, we really don't care if something goes wrong
        UI.error(caller.join("\n\t"))
        UI.error("Could not fetch #{key} from project file: #{ex}")
      end

      nil
    end

    # Returns the build settings and sets the default scheme to the options hash
    def default_build_settings(key: nil, optional: true)
      options[:scheme] ||= schemes.first if is_workspace
      build_settings(key: key, optional: optional)
    end

    private

    def parsed_info
      unless @parsed_info
        @parsed_info = self.xcodebuild.list
      end
      @parsed_info
    end

    # If scheme not specified, do we want the scheme
    # matching project name?
    def automated_scheme_selection?
      FastlaneCore::Env.truthy?("AUTOMATED_SCHEME_SELECTION")
    end
  end
end
