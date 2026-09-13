# frozen_string_literal: true

require_relative "test_helper"

describe MermaidPreview::Paths do
  let(:paths) { MermaidPreview::Paths }

  it "honours XDG_CONFIG_HOME" do
    with_env({"XDG_CONFIG_HOME" => "/xdg"}) do
      _(paths.config_dir).must_equal "/xdg/mmd-preview"
    end
  end

  it "falls back to ~/.config" do
    with_env({"XDG_CONFIG_HOME" => nil}) do
      _(paths.config_dir).must_equal File.join(Dir.home, ".config/mmd-preview")
    end
  end

  it "reads the environment on every call rather than at load time" do
    first = with_env({"XDG_CONFIG_HOME" => "/one"}) { paths.config_dir }
    second = with_env({"XDG_CONFIG_HOME" => "/two"}) { paths.config_dir }

    _([first, second]).must_equal ["/one/mmd-preview", "/two/mmd-preview"]
  end

  it "puts the puppeteer config inside the config dir" do
    with_env({"XDG_CONFIG_HOME" => "/xdg"}) do
      _(paths.puppeteer_config).must_equal "/xdg/mmd-preview/puppeteer.json"
    end
  end
end
