describe FastlaneCore do
  describe FastlaneCore::XcodebuildShowbuildsettingsOutputParser do
    it "parses standard output" do
      output = %(Build settings for action build and target target_A:
    ACTION = build
    PRODUCT_BUNDLE_IDENTIFIER = com.sample.target.a

Build settings for action build and target "target B":
    ACTION = build
    PRODUCT_BUNDLE_IDENTIFIER = com.sample.target.b
)
      parsed = FastlaneCore::XcodebuildShowbuildsettingsOutputParser.new(output)
      expect(parsed['target_A']).to eq("Build settings for action build and target target_A:\n    ACTION = build\n    PRODUCT_BUNDLE_IDENTIFIER = com.sample.target.a\n")
      expect(parsed['target B']).to eq("\nBuild settings for action build and target \"target B\":\n    ACTION = build\n    PRODUCT_BUNDLE_IDENTIFIER = com.sample.target.b\n")
    end
  end
end
