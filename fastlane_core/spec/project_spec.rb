describe FastlaneCore do
  describe FastlaneCore::Project do
    describe 'project and workspace detection' do
      def within_a_temp_dir
        Dir.mktmpdir do |dir|
          FileUtils.cd(dir) do
            yield dir if block_given?
          end
        end
      end

      let(:options) do
        [
          FastlaneCore::ConfigItem.new(key: :project, description: "Project", optional: true),
          FastlaneCore::ConfigItem.new(key: :workspace, description: "Workspace", optional: true)
        ]
      end

      it 'raises if both project and workspace are specified' do
        expect do
          config = FastlaneCore::Configuration.new(options, { project: 'yup', workspace: 'yeah' })
          FastlaneCore::Project.detect_projects(config)
        end.to raise_error(FastlaneCore::Interface::FastlaneError, "You can only pass either a workspace or a project path, not both")
      end

      it 'keeps the specified project' do
        config = FastlaneCore::Configuration.new(options, { project: 'yup' })
        FastlaneCore::Project.detect_projects(config)

        expect(config[:project]).to eq('yup')
        expect(config[:workspace]).to be_nil
      end

      it 'keeps the specified workspace' do
        config = FastlaneCore::Configuration.new(options, { workspace: 'yeah' })
        FastlaneCore::Project.detect_projects(config)

        expect(config[:project]).to be_nil
        expect(config[:workspace]).to eq('yeah')
      end

      it 'picks the only workspace file present' do
        within_a_temp_dir do |dir|
          workspace = './Something.xcworkspace'
          FileUtils.mkdir_p(workspace)

          config = FastlaneCore::Configuration.new(options, {})
          FastlaneCore::Project.detect_projects(config)

          expect(config[:workspace]).to eq(workspace)
        end
      end

      it 'picks the only project file present' do
        within_a_temp_dir do |dir|
          project = './Something.xcodeproj'
          FileUtils.mkdir_p(project)

          config = FastlaneCore::Configuration.new(options, {})
          FastlaneCore::Project.detect_projects(config)

          expect(config[:project]).to eq(project)
        end
      end

      it 'prompts to select among multiple workspace files' do
        within_a_temp_dir do |dir|
          workspaces = ['./Something.xcworkspace', './SomethingElse.xcworkspace']
          FileUtils.mkdir_p(workspaces)

          expect(FastlaneCore::Project).to receive(:choose).and_return(workspaces.last)
          expect(FastlaneCore::Project).not_to receive(:select_project)

          config = FastlaneCore::Configuration.new(options, {})
          FastlaneCore::Project.detect_projects(config)

          expect(config[:workspace]).to eq(workspaces.last)
        end
      end

      it 'prompts to select among multiple project files' do
        within_a_temp_dir do |dir|
          projects = ['./Something.xcodeproj', './SomethingElse.xcodeproj']
          FileUtils.mkdir_p(projects)

          expect(FastlaneCore::Project).to receive(:choose).and_return(projects.last)
          expect(FastlaneCore::Project).not_to receive(:select_project)

          config = FastlaneCore::Configuration.new(options, {})
          FastlaneCore::Project.detect_projects(config)

          expect(config[:project]).to eq(projects.last)
        end
      end

      it 'asks the user to specify a project when none are found' do
        within_a_temp_dir do |dir|
          project = './subdir/Something.xcodeproj'
          FileUtils.mkdir_p(project)

          expect(FastlaneCore::UI).to receive(:input).and_return(project)

          config = FastlaneCore::Configuration.new(options, {})
          FastlaneCore::Project.detect_projects(config)

          expect(config[:project]).to eq(project)
        end
      end

      it 'asks the user to specify a workspace when none are found' do
        within_a_temp_dir do |dir|
          workspace = './subdir/Something.xcworkspace'
          FileUtils.mkdir_p(workspace)

          expect(FastlaneCore::UI).to receive(:input).and_return(workspace)

          config = FastlaneCore::Configuration.new(options, {})
          FastlaneCore::Project.detect_projects(config)

          expect(config[:workspace]).to eq(workspace)
        end
      end

      it 'explains when a provided path is not found' do
        within_a_temp_dir do |dir|
          workspace = './subdir/Something.xcworkspace'
          FileUtils.mkdir_p(workspace)

          expect(FastlaneCore::UI).to receive(:input).and_return("something wrong")
          expect(FastlaneCore::UI).to receive(:error).with(/Couldn't find/)
          expect(FastlaneCore::UI).to receive(:input).and_return(workspace)

          config = FastlaneCore::Configuration.new(options, {})
          FastlaneCore::Project.detect_projects(config)

          expect(config[:workspace]).to eq(workspace)
        end
      end

      it 'explains when a provided path is not valid' do
        within_a_temp_dir do |dir|
          workspace = './subdir/Something.xcworkspace'
          FileUtils.mkdir_p(workspace)
          FileUtils.mkdir_p('other-directory')

          expect(FastlaneCore::UI).to receive(:input).and_return('other-directory')
          expect(FastlaneCore::UI).to receive(:error).with(/Path must end with/)
          expect(FastlaneCore::UI).to receive(:input).and_return(workspace)

          config = FastlaneCore::Configuration.new(options, {})
          FastlaneCore::Project.detect_projects(config)

          expect(config[:workspace]).to eq(workspace)
        end
      end
    end

    it "raises an exception if path was not found" do
      expect do
        FastlaneCore::Project.new(project: "/tmp/notHere123")
      end.to raise_error "Could not find project at path '/tmp/notHere123'"
    end

    describe "Valid Standard Project" do
      before do
        options = { project: "./fastlane_core/spec/fixtures/projects/Example.xcodeproj" }
        @project = FastlaneCore::Project.new(options, xcodebuild_list_silent: true, xcodebuild_suppress_stderr: true)
      end

      it "#path" do
        expect(@project.path).to eq(File.expand_path("./fastlane_core/spec/fixtures/projects/Example.xcodeproj"))
      end

      it "#is_workspace" do
        expect(@project.is_workspace).to eq(false)
      end

      it "#project_name" do
        expect(@project.project_name).to eq("Example")
      end

      it "#schemes returns all available schemes" do
        expect(@project.schemes).to eq(["Example"])
      end

      it "#configurations returns all available configurations" do
        expect(@project.configurations).to eq(["Debug", "Release", "SpecialConfiguration"])
      end

      it "#app_name" do
        expect(@project.app_name).to eq("ExampleProductName")
      end

      it "#mac?" do
        expect(@project.mac?).to eq(false)
      end

      it "#ios?" do
        expect(@project.ios?).to eq(true)
      end

      it "#tvos?" do
        expect(@project.tvos?).to eq(false)
      end
    end

    describe "Valid CocoaPods Project" do
      before do
        options = {
          workspace: "./fastlane_core/spec/fixtures/projects/cocoapods/Example.xcworkspace",
          scheme: "Example"
        }
        @workspace = FastlaneCore::Project.new(options, xcodebuild_list_silent: true, xcodebuild_suppress_stderr: true)
      end

      it "#schemes returns all schemes" do
        expect(@workspace.schemes).to eq(["Example"])
      end

      it "#schemes returns all configurations" do
        expect(@workspace.configurations).to eq([])
      end
    end

    describe "Mac Project" do
      before do
        options = { project: "./fastlane_core/spec/fixtures/projects/Mac.xcodeproj" }
        @project = FastlaneCore::Project.new(options, xcodebuild_list_silent: true, xcodebuild_suppress_stderr: true)
      end

      it "#mac?" do
        expect(@project.mac?).to eq(true)
      end

      it "#ios?" do
        expect(@project.ios?).to eq(false)
      end

      it "#tvos?" do
        expect(@project.tvos?).to eq(false)
      end

      it "schemes" do
        expect(@project.schemes).to eq(["Mac"])
      end
    end

    describe "TVOS Project" do
      before do
        options = { project: "./fastlane_core/spec/fixtures/projects/ExampleTVOS.xcodeproj" }
        @project = FastlaneCore::Project.new(options, xcodebuild_list_silent: true, xcodebuild_suppress_stderr: true)
      end

      it "#mac?" do
        expect(@project.mac?).to eq(false)
      end

      it "#ios?" do
        expect(@project.ios?).to eq(false)
      end

      it "#tvos?" do
        expect(@project.tvos?).to eq(true)
      end

      it "schemes" do
        expect(@project.schemes).to eq(["ExampleTVOS"])
      end
    end

    describe "Cross-Platform Project" do
      before do
        options = { project: "./fastlane_core/spec/fixtures/projects/Cross-Platform.xcodeproj" }
        @project = FastlaneCore::Project.new(options, xcodebuild_list_silent: true, xcodebuild_suppress_stderr: true)
      end

      it "supported_platforms" do
        expect(@project.supported_platforms).to eq([:macOS, :iOS, :tvOS, :watchOS])
      end

      it "#mac?" do
        expect(@project.mac?).to eq(true)
      end

      it "#ios?" do
        expect(@project.ios?).to eq(true)
      end

      it "#tvos?" do
        expect(@project.tvos?).to eq(true)
      end

      it "schemes" do
        expect(@project.schemes).to eq(["CrossPlatformFramework"])
      end
    end

    describe "build_settings() can handle empty lines" do
      let(:project) do
        options = { project: "./fastlane_core/spec/fixtures/projects/Example.xcodeproj" }
        FastlaneCore::Project.new(options, xcodebuild_list_silent: true, xcodebuild_suppress_stderr: true)
      end

      it "SUPPORTED_PLATFORMS should be iphonesimulator iphoneos on Xcode >= 8.3" do
        expect(FastlaneCore::Helper).to receive(:xcode_at_least?).and_return(true)
        command = "xcodebuild -showBuildSettings -alltargets -project ./fastlane_core/spec/fixtures/projects/Example.xcodeproj 2> /dev/null"
        expect(FastlaneCore::Xcodebuild).to receive(:run_command).with(command.to_s, { timeout: 10, retries: 3, print: false }).and_return(File.read("./fastlane_core/spec/fixtures/projects/build_settings_with_toolchains"))

        expect(project.build_settings(key: "SUPPORTED_PLATFORMS", target: 'app')).to eq("iphonesimulator iphoneos")
      end

      it "SUPPORTED_PLATFORMS should be iphonesimulator iphoneos on Xcode < 8.3" do
        expect(FastlaneCore::Helper).to receive(:xcode_at_least?).and_return(false)
        command = "xcodebuild -showBuildSettings -alltargets -project ./fastlane_core/spec/fixtures/projects/Example.xcodeproj clean 2> /dev/null"
        expect(FastlaneCore::Xcodebuild).to receive(:run_command).with(command.to_s, { timeout: 10, retries: 3, print: false }).and_return(File.read("./fastlane_core/spec/fixtures/projects/build_settings_with_toolchains"))
        expect(project.build_settings(key: "SUPPORTED_PLATFORMS", target: 'app')).to eq("iphonesimulator iphoneos")
      end
    end

    describe "Build Settings with default configuration" do
      before do
        options = { project: "./fastlane_core/spec/fixtures/projects/Example.xcodeproj" }
        @project = FastlaneCore::Project.new(options, xcodebuild_list_silent: true, xcodebuild_suppress_stderr: true)
      end

      it "IPHONEOS_DEPLOYMENT_TARGET should be 9.0" do
        expect(@project.build_settings(key: "IPHONEOS_DEPLOYMENT_TARGET")).to eq("9.0")
      end

      it "PRODUCT_BUNDLE_IDENTIFIER should be tools.fastlane.app" do
        expect(@project.build_settings(key: "PRODUCT_BUNDLE_IDENTIFIER")).to eq("tools.fastlane.app")
      end
    end

    describe "Build Settings with specific configuration" do
      before do
        options = {
          project: "./fastlane_core/spec/fixtures/projects/Example.xcodeproj",
          configuration: "SpecialConfiguration"
        }
        @project = FastlaneCore::Project.new(options, xcodebuild_list_silent: true, xcodebuild_suppress_stderr: true)
      end

      it "IPHONEOS_DEPLOYMENT_TARGET should be 9.0" do
        expect(@project.build_settings(key: "IPHONEOS_DEPLOYMENT_TARGET")).to eq("9.0")
      end

      it "PRODUCT_BUNDLE_IDENTIFIER should be tools.fastlane.app.special" do
        expect(@project.build_settings(key: "PRODUCT_BUNDLE_IDENTIFIER")).to eq("tools.fastlane.app.special")
      end
    end
  end
end
