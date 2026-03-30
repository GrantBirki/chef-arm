# frozen_string_literal: true

require "spec_helper"

RSpec.describe ChefArm::ReleaseMetadata do
  it "normalizes the version and creates release names" do
    metadata = described_class.new(version: "v15.17.0", iteration: 2)

    expect(metadata.version).to eq("15.17.0")
    expect(metadata.release_tag).to eq("v15.17.0-arm64.2")
    expect(metadata.package_filename).to eq("chef-server-core_15.17.0-2_arm64.deb")
  end

  it "supports a custom package prefix" do
    metadata = described_class.new(version: "15.17.0", iteration: 1, prefix: "custom-chef-server")

    expect(metadata.package_filename).to eq("custom-chef-server_15.17.0-1_arm64.deb")
  end

  it "serializes metadata for release automation" do
    metadata = described_class.new(version: "15.17.0", iteration: 3)

    expect(metadata.to_h).to eq(
      {
        "iteration" => 3,
        "package_filename" => "chef-server-core_15.17.0-3_arm64.deb",
        "release_tag" => "v15.17.0-arm64.3",
        "version" => "15.17.0"
      }
    )
  end
end
