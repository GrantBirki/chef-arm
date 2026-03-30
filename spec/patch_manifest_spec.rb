# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe ChefArm::PatchManifest do
  it "returns common, matching constraint, and ref-specific patches" do
    Dir.mktmpdir do |dir|
      manifest_path = File.join(dir, "patches.yml")
      File.write(
        manifest_path,
        <<~YAML
          ---
          patches:
            common:
              - patches/common/0001.patch
            constraints:
              - requirement: "~> 15.10.0"
                patches:
                  - patches/common/constraint.patch
            refs:
              15.10.93:
                - patches/15.10.93/0002.patch
        YAML
      )

      manifest = described_class.load(manifest_path)

      expect(
        manifest.patches_for(ref: "15.10.93", version: "15.10.93")
      ).to eq(
        [
          "patches/common/0001.patch",
          "patches/common/constraint.patch",
          "patches/15.10.93/0002.patch"
        ]
      )
    end
  end

  it "returns an empty patch list when no sections match" do
    Dir.mktmpdir do |dir|
      manifest_path = File.join(dir, "patches.yml")
      File.write(manifest_path, "---\npatches:\n  common: []\n  constraints: []\n  refs: {}\n")

      manifest = described_class.load(manifest_path)

      expect(manifest.patches_for(ref: "v1.0.0", version: "1.0.0")).to eq([])
    end
  end
end
