describe FastlaneCore do
  describe FastlaneCore::Xcodebuild do
    describe "Xcodebuild.list_timeout" do
      before do
        ENV['FASTLANE_XCODE_LIST_TIMEOUT'] = nil
      end
      it "returns default value" do
        expect(FastlaneCore::Xcodebuild.list_timeout).to eq(10)
      end
      it "returns specified value" do
        ENV['FASTLANE_XCODE_LIST_TIMEOUT'] = '5'
        expect(FastlaneCore::Xcodebuild.list_timeout).to eq(5)
      end
      it "returns 0 if empty" do
        ENV['FASTLANE_XCODE_LIST_TIMEOUT'] = ''
        expect(FastlaneCore::Xcodebuild.list_timeout).to eq(0)
      end
      it "returns 0 if garbage" do
        ENV['FASTLANE_XCODE_LIST_TIMEOUT'] = 'hiho'
        expect(FastlaneCore::Xcodebuild.list_timeout).to eq(0)
      end
    end

    describe 'Xcodebuild.build_settings_timeout' do
      before do
        ENV['FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT'] = nil
      end
      it "returns default value" do
        expect(FastlaneCore::Xcodebuild.settings_timeout).to eq(10)
      end
      it "returns specified value" do
        ENV['FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT'] = '5'
        expect(FastlaneCore::Xcodebuild.settings_timeout).to eq(5)
      end
      it "returns 0 if empty" do
        ENV['FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT'] = ''
        expect(FastlaneCore::Xcodebuild.settings_timeout).to eq(0)
      end
      it "returns 0 if garbage" do
        ENV['FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT'] = 'hiho'
        expect(FastlaneCore::Xcodebuild.settings_timeout).to eq(0)
      end
    end

    describe 'Xcodebuild.build_settings_retries' do
      before do
        ENV['FASTLANE_XCODEBUILD_SETTINGS_RETRIES'] = nil
      end
      it "returns default value" do
        expect(FastlaneCore::Xcodebuild.settings_retries).to eq(3)
      end
      it "returns specified value" do
        ENV['FASTLANE_XCODEBUILD_SETTINGS_RETRIES'] = '5'
        expect(FastlaneCore::Xcodebuild.settings_retries).to eq(5)
      end
      it "returns 0 if empty" do
        ENV['FASTLANE_XCODEBUILD_SETTINGS_RETRIES'] = ''
        expect(FastlaneCore::Xcodebuild.settings_retries).to eq(0)
      end
      it "returns 0 if garbage" do
        ENV['FASTLANE_XCODEBUILD_SETTINGS_RETRIES'] = 'hiho'
        expect(FastlaneCore::Xcodebuild.settings_retries).to eq(0)
      end
    end

    describe 'xcodebuild_suppress_stderr option' do
      it 'generates an xcodebuild -list command without stderr redirection by default' do
        xcodebuild = FastlaneCore::Xcodebuild.new({ options: { project: "./fastlane_core/spec/fixtures/xcodebuilds/Example.xcodeproj" } })
        expect(xcodebuild.list_command).not_to match(%r{2> /dev/null})
      end

      it 'generates an xcodebuild -list command that redirects stderr to /dev/null' do
        xcodebuild = FastlaneCore::Xcodebuild.new(
          { options: { xcodebuild: "./fastlane_core/spec/fixtures/xcodebuilds/Example.xcodeproj" } },
          xcodebuild_suppress_stderr: true
        )
        expect(xcodebuild.list_command).to match(%r{2> /dev/null})
      end

      it 'generates an xcodebuild -showBuildSettings command without stderr redirection by default' do
        xcodebuild = FastlaneCore::Xcodebuild.new({ xcodebuild: "./fastlane_core/spec/fixtures/xcodebuilds/Example.xcodeproj" })
        expect(xcodebuild.showbuildsettings_command).not_to match(%r{2> /dev/null})
      end

      it 'generates an xcodebuild -showBuildSettings command that redirects stderr to /dev/null' do
        xcodebuild = FastlaneCore::Xcodebuild.new(
          { xcodebuild: "./fastlane_core/spec/fixtures/xcodebuilds/Example.xcodeproj" },
          xcodebuild_suppress_stderr: true
        )
        expect(xcodebuild.showbuildsettings_command).to match(%r{2> /dev/null})
      end
    end

    describe "Xcodebuild.run_command" do
      def count_processes(text)
        `ps -aef | grep #{text} | grep -v grep | wc -l`.to_i
      end

      it "runs simple commands" do
        cmd = 'echo "HO"'
        expect(FastlaneCore::Xcodebuild.run_command(cmd)).to eq("HO\n")
      end

      it "runs more complicated commands" do
        cmd = "ruby -e 'sleep 0.1; puts \"HI\"'"
        expect(FastlaneCore::Xcodebuild.run_command(cmd)).to eq("HI\n")
      end

      it "should timeouts and kills" do
        text = "FOOBAR" # random text
        count = count_processes(text)
        cmd = "ruby -e 'sleep 3; puts \"#{text}\"'"
        # this doesn't work
        expect do
          FastlaneCore::Xcodebuild.run_command(cmd, timeout: 1)
        end.to raise_error(Timeout::Error)

        # this shows the current implementation issue
        # Timeout doesn't kill the running process
        # i.e. see fastlane/fastlane_core#102
        expect(count_processes(text)).to eq(count + 1)
        sleep(5)
        expect(count_processes(text)).to eq(count)
        # you would be expected to be able to see the number of processes go back to count right away.
      end

      it "retries and kills" do
        text = "NEEDSRETRY"
        cmd = "ruby -e 'sleep 3; puts \"#{text}\"'"

        expect(FastlaneCore::Xcodebuild).to receive(:`).and_call_original.exactly(4).times

        expect do
          FastlaneCore::Xcodebuild.run_command(cmd, timeout: 1, retries: 3)
        end.to raise_error(Timeout::Error)
      end
    end

  end
end
