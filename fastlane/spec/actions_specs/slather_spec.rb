describe Fastlane do
  describe Fastlane::FastFile do
    describe "Slather Integration" do
      it "works with all parameters" do
        result = Fastlane::FastFile.new.parse("lane :test do
          slather({
            use_bundle_exec: false,
            build_directory: 'foo',
            input_format: 'bah',
            scheme: 'Foo',
            buildkite: true,
            jenkins: true,
            travis: true,
            circleci: true,
            coveralls: true,
            teamcity: true,
            simple_output: true,
            gutter_json: true,
            cobertura_xml: true,
            html: true,
            show: true,
            verbose: true,
            source_directory: 'baz',
            output_directory: '123',
            ignore: 'nothing',
            proj: 'foo.xcodeproj',
            binary_basename: 'YourApp',
            binary_file: 'you',
            workspace: 'foo.xcworkspace',
            source_files: '*.swift',
            decimals: '2'
          })
        end").runner.execute(:test)

        expected = "slather coverage
                    --travis
                    --circleci
                    --jenkins
                    --buildkite
                    --teamcity
                    --coveralls
                    --simple-output
                    --gutter-json
                    --cobertura-xml
                    --html
                    --show
                    --build-directory foo
                    --source-directory baz
                    --output-directory 123
                    --ignore nothing
                    --verbose
                    --input-format bah
                    --scheme Foo
                    --workspace foo.xcworkspace
                    --binary-file you
                    --binary-basename YourApp
                    --source-files \\*.swift
                    --decimals 2 foo.xcodeproj".gsub(/\s+/, ' ')
        expect(result).to eq(expected)
      end

      it "works with bundle" do
        allow(FastlaneCore::FastlaneFolder).to receive(:path).and_return(nil)
        result = Fastlane::FastFile.new.parse("lane :test do
          slather({
            use_bundle_exec: true,
            build_directory: 'foo',
            input_format: 'bah',
            scheme: 'Foo',
            buildkite: true,
            jenkins: true,
            travis: true,
            circleci: true,
            coveralls: true,
            simple_output: true,
            gutter_json: true,
            cobertura_xml: true,
            html: true,
            show: true,
            source_directory: 'baz',
            output_directory: '123',
            ignore: 'nothing',
            proj: 'foo.xcodeproj',
            binary_basename: 'YourApp',
            binary_file: 'you',
            workspace: 'foo.xcworkspace'
          })
        end").runner.execute(:test)

        expected = 'bundle exec slather coverage
                    --travis
                    --circleci
                    --jenkins
                    --buildkite
                    --coveralls
                    --simple-output
                    --gutter-json
                    --cobertura-xml
                    --html
                    --show
                    --build-directory foo
                    --source-directory baz
                    --output-directory 123
                    --ignore nothing
                    --input-format bah
                    --scheme Foo
                    --workspace foo.xcworkspace
                    --binary-file you
                    --binary-basename YourApp foo.xcodeproj'.gsub(/\s+/, ' ')
        expect(result).to eq(expected)
      end

      it "requires project to be specified if .slather.yml is not found" do
        expect do
          Fastlane::FastFile.new.parse("lane :test do
            slather
          end").runner.execute(:test)
        end.to raise_error(FastlaneCore::Interface::FastlaneError)
      end

      it "does not require project if .slather.yml is found" do
        allow(FastlaneCore::FastlaneFolder).to receive(:path).and_return(nil)
        File.write('./.slather.yml', '')

        result = Fastlane::FastFile.new.parse("lane :test do
          slather
        end").runner.execute(:test)

        expect(result).to eq("slather coverage")
      end

      it "does not require any parameters other than project" do
        result = Fastlane::FastFile.new.parse("lane :test do
          slather({
            proj: 'foo.xcodeproj'
          })
        end").runner.execute(:test)

        expect(result).to eq("slather coverage foo.xcodeproj")
      end

      it "works with spaces in paths" do
        result = Fastlane::FastFile.new.parse("lane :test do
          slather({
            build_directory: 'build dir',
            input_format: 'bah',
            scheme: 'Foo App',
            source_directory: 'source dir',
            output_directory: 'output dir',
            ignore: 'nothing to ignore',
            proj: 'foo bar.xcodeproj'
          })
        end").runner.execute(:test)

        expected = "slather coverage
                    --build-directory build\\ dir
                    --source-directory source\\ dir
                    --output-directory output\\ dir
                    --ignore nothing\\ to\\ ignore
                    --input-format bah
                    --scheme Foo\\ App
                    foo\\ bar.xcodeproj".gsub(/\s+/, ' ')

        expect(result).to eq(expected)
      end

      it "works with multiple ignore patterns" do
        result = Fastlane::FastFile.new.parse("lane :test do
          slather({
            ignore: ['Pods/*', '../**/*/Xcode*'],
            proj: 'foo.xcodeproj'
          })
        end").runner.execute(:test)

        expect(result).to eq("slather coverage --ignore Pods/\\* --ignore ../\\*\\*/\\*/Xcode\\* foo.xcodeproj")
      end

      context 'when SharedValues::SCAN_STATUS_EXCEPTION is true' do
        it 'skipping slather' do
          Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::SCAN_STATUS_EXCEPTION] = true
          result = Fastlane::FastFile.new.parse("lane :test do
            slather({
              scheme: 'Foo App',
              proj: 'foo bar.xcodeproj'
            })
          end").runner.execute(:test)
          expect(result).to be_nil
        end
      end

      after(:each) do
        File.delete('./.slather.yml') if File.exist?("./.slather.yml")
      end
    end
  end
end
