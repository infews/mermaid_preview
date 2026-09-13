# frozen_string_literal: true

module MermaidPreview
  # Where mmd-preview-init leaves the things this tool reads. Methods rather
  # than constants so XDG_CONFIG_HOME is honoured whenever it's asked for.
  module Paths
    module_function

    def config_home = ENV["XDG_CONFIG_HOME"] || File.join(Dir.home, ".config")

    def config_dir = File.join(config_home, "mmd-preview")

    def puppeteer_config = File.join(config_dir, "puppeteer.json")
  end
end
