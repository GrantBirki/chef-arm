# frozen_string_literal: true

require "rubygems"
require "yaml"

module ChefArm
  class PatchManifest
    class Constraint
      def initialize(entry)
        @requirement = Gem::Requirement.new(entry.fetch("requirement"))
        @patches = Array(entry.fetch("patches", [])).map(&:to_s)
      end

      def matches?(version)
        @requirement.satisfied_by?(Gem::Version.new(normalize_version(version)))
      end

      attr_reader :patches

      private

      def normalize_version(version)
        version.to_s.sub(/\Av/, "")
      end
    end

    def self.load(path)
      document = YAML.safe_load_file(path, aliases: false) || {}
      new(document.fetch("patches", {}))
    end

    def initialize(data)
      @common = Array(data.fetch("common", [])).map(&:to_s)
      @constraints = Array(data.fetch("constraints", [])).map { |entry| Constraint.new(entry) }
      @refs = data.fetch("refs", {}).transform_values { |patches| Array(patches).map(&:to_s) }
    end

    def patches_for(ref:, version:)
      [
        *@common,
        *@constraints.select { |constraint| constraint.matches?(version) }.flat_map(&:patches),
        *@refs.fetch(ref.to_s, [])
      ]
    end
  end
end
