module FastlaneCore
  class XcodebuildShowbuildsettingsOutputParser
    attr_reader :targets

    # Examples:
    #
    # Build settings for action build and target target_A:
    #     ACTION = build
    #     .
    #     .
    #     arch = arm64
    #     diagnostic_message_length = 203
    #     variant = normal
    #
    # Build settings for action build and target "target B":
    #     ACTION = build
    #     AD_HOC_CODE_SIGNING_ALLOWED = NO
    #     ALTERNATE_GROUP = staff
    #     ALTERNATE_MODE = u+w,go-w,a+rX
    #     ALTERNATE_OWNER = owner
    #     .
    #
    def initialize(output)
      @targets = {}
      output.split(/^$/).each do |section|
        if section =~ /Build settings for action .+ and target "?(.+?)"?:/
          current_target = $1
          @targets[current_target] = section
        end
      end
    end
  end
end
