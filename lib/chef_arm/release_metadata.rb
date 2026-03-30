# frozen_string_literal: true

module ChefArm
  class ReleaseMetadata
    DEFAULT_PREFIX = "chef-server-core"

    def initialize(version:, iteration:, prefix: DEFAULT_PREFIX)
      @version = normalize_version(version)
      @iteration = Integer(iteration)
      @prefix = prefix
    end

    attr_reader :iteration, :prefix, :version

    def package_filename
      "#{prefix}_#{version}-#{iteration}_arm64.deb"
    end

    def release_tag
      "v#{version}-arm64.#{iteration}"
    end

    def to_h
      {
        "iteration" => iteration,
        "package_filename" => package_filename,
        "release_tag" => release_tag,
        "version" => version
      }
    end

    private

    def normalize_version(version)
      version.to_s.sub(/\Av/, "")
    end
  end
end
