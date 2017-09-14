require 'xcodeproj'

module Gym
  class CodeSigningMapping
    attr_accessor :project

    attr_accessor :project_paths

    def initialize(project: nil)
      self.project = project
    end

    # @param primary_mapping [Hash] The preferred mapping (e.g. whatever the user provided)
    # @param secondary_mapping [Hash] (optional) The secondary mapping (e.g. whatever is detected from the Xcode project)
    # @param export_method [String] The method that should be preferred in case there is a conflict
    def merge_profile_mapping(primary_mapping: nil, secondary_mapping: nil, export_method: nil)
      final_mapping = (primary_mapping || {}).dup # for verbose output at the end of the method
      secondary_mapping ||= self.detect_project_profile_mapping # default to Xcode project

      final_mapping = Hash[final_mapping.map { |k, v| [k.to_sym, v] }]
      secondary_mapping = Hash[secondary_mapping.map { |k, v| [k.to_sym, v] }]

      # Now it's time to merge the (potentially) existing mapping
      #   (e.g. coming from `provisioningProfiles` of the `export_options` or from previous match calls)
      # with the secondary hash we just created (or was provided as parameter).
      # Both might include information about what profile to use
      # This is important as it mght not be clear for the user that they have to call match for each app target
      # before adding this code, we'd only either use whatever we get from match, or what's defined in the Xcode project
      # With the code below, we'll make sure to take the best of it:
      #
      #   1) A provisioning profile is defined in the `primary_mapping`
      #   2) A provisioning profile is defined in the `secondary_mapping`
      #   3) On a conflict (app identifier assigned both in xcode and match)
      #     3.1) we'll choose whatever matches what's defined as the `export_method`
      #     3.2) If both include the right `export_method`, we'll prefer the one from `primary_mapping`
      #     3.3) If none has the right export_method, we'll use whatever is defined in the Xcode project
      #
      # To get a better sense of this, check out code_signing_spec.rb for some test cases

      secondary_mapping.each do |bundle_identifier, provisioning_profile|
        if final_mapping[bundle_identifier].nil?
          final_mapping[bundle_identifier] = provisioning_profile
        else
          if self.app_identifier_contains?(final_mapping[bundle_identifier], export_method) # 3.1 + 3.2 nothing to do in this case
          elsif self.app_identifier_contains?(provisioning_profile, export_method)
            # Also 3.1 (3.1 is "implemented" twice, as it could be either the primary, or the secondary being the one that matches)
            final_mapping[bundle_identifier] = provisioning_profile
          else
            # 3.3
            final_mapping[bundle_identifier] = provisioning_profile
          end
        end
      end

      UI.verbose("Merging provisioning profile mappings")
      UI.verbose("-------------------------------------")
      UI.verbose("Primary provisioning profile mapping:")
      UI.verbose(primary_mapping)
      UI.verbose("Secondary provisioning profile mapping:")
      UI.verbose(secondary_mapping)
      UI.verbose("Resulting in the following mapping:")
      UI.verbose(final_mapping)

      return final_mapping
    end

    # Helper method to remove "-" and " " and downcase app identifier
    # and compare if an app identifier includes a certain string
    # We do some `gsub`bing, because we can't really know the profile type, so we'll just look at the name and see if it includes
    # the export method (which it usually does, but with different notations)
    def app_identifier_contains?(str, contains)
      return str.to_s.gsub("-", "").gsub(" ", "").downcase.include?(contains.to_s.gsub("-", "").gsub(" ", "").downcase)
    end

    # Array of paths to all project files
    # (might be multiple, because of workspaces)
    def project_paths
      return @_project_paths if @_project_paths
      if self.project.workspace?
        # Find the xcodeproj file, as the information isn't included in the workspace file
        # We have a reference to the workspace, let's find the xcodeproj file
        # For some reason the `plist` gem can't parse the content file
        # so we'll use a regex to find all group references

        workspace_data_path = File.join(self.project.path, "contents.xcworkspacedata")
        workspace_data = File.read(workspace_data_path)
        @_project_paths = workspace_data.scan(/\"group:(.*)\"/).collect do |current_match|
          # It's a relative path from the workspace file
          File.join(File.expand_path("..", self.project.path), current_match.first)
        end.find_all do |current_match|
          # We're not interested in a `Pods` project, as it doesn't contain any relevant
          # information about code signing
          !current_match.end_with?("Pods/Pods.xcodeproj")
        end

        return @_project_paths
      else
        # Return the path as an array
        return @_project_paths = [self.project.path]
      end
    end

    def detect_project_profile_mapping
      provisioning_profile_mapping = {}
      specified_configuration = Gym.config[:configuration] || self.project.default_build_settings(key: "CONFIGURATION")

      self.project_paths.each do |project_path|
        UI.verbose("Parsing project file '#{project_path}' to find selected provisioning profiles")
        UI.verbose("Finding provision profiles for '#{specified_configuration}'") if specified_configuration

        begin
          # Storing bundle identifiers with duplicate profiles
          # for informing user later on
          bundle_identifiers_with_duplicates = []

          project = Xcodeproj::Project.open(project_path)
          project.targets.each do |target|
            next if self.project.test?(target: target.name)

            bundle_identifier = self.project.build_settings(target: target.name, key: "PRODUCT_BUNDLE_IDENTIFIER")
            provisioning_profile_specifier = self.project.build_settings(target: target.name, key: "PROVISIONING_PROFILE_SPECIFIER")
            provisioning_profile_uuid = self.project.build_settings(target: target.name, key: "PROVISIONING_PROFILE")

            has_profile_specifier = provisioning_profile_specifier.to_s.length > 0
            has_profile_uuid = provisioning_profile_uuid.to_s.length > 0

            # Stores bundle identifiers that have already been mapped to inform user
            if provisioning_profile_mapping[bundle_identifier] && (has_profile_specifier || has_profile_uuid)
              bundle_identifiers_with_duplicates << bundle_identifier
            end

            # Creates the mapping for a bundle identifier and profile specifier/uuid
            if has_profile_specifier
              provisioning_profile_mapping[bundle_identifier] = provisioning_profile_specifier
            elsif has_profile_uuid
              provisioning_profile_mapping[bundle_identifier] = provisioning_profile_uuid
            end

            # Alerting user to explicitly specify a mapping if cannot be determined
            next if bundle_identifiers_with_duplicates.empty?
            UI.error("Couldn't automatically detect the provisioning profile mapping")
            UI.error("There were multiple profiles for bundle identifier(s): #{bundle_identifiers_with_duplicates.uniq.join(', ')}")
            UI.error("You need to provide an explicit mapping of what provisioning")
            UI.error("profile to use for each bundle identifier of your app")
          end
        rescue => ex
          # We catch errors here, as we might run into an exception on one included project
          # But maybe the next project actually contains the information we need
          if Helper.xcode_at_least?("9.0")
            UI.error("Couldn't automatically detect the provisioning profile mapping")
            UI.error("Since Xcode 9 you need to provide an explicit mapping of what")
            UI.error("provisioning profile to use for each target of your app")
            UI.error(ex)
            UI.verbose(ex.backtrace.join("\n"))
          end
        end
      end
      return provisioning_profile_mapping
    end
  end
end
