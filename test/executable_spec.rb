# frozen_string_literal: true

require_relative "test_helper"

describe MermaidPreview::Executable do
  let(:executable) { MermaidPreview::Executable }

  describe ".find" do
    it "returns the first match in PATH order" do
      first, second = mkdirs(tmpdir, "first", "second")
      make_executable(first, "widget")
      make_executable(second, "widget")

      with_path(first, second) { _(executable.find("widget")).must_equal File.join(first, "widget") }
    end

    it "walks past directories that do not hold the command" do
      empty, holder = mkdirs(tmpdir, "empty", "holder")
      make_executable(holder, "widget")

      with_path(empty, holder) { _(executable.find("widget")).must_equal File.join(holder, "widget") }
    end

    it "ignores a file that is not executable" do
      bin = mkdirs(tmpdir, "bin").first
      File.write(File.join(bin, "widget"), "not executable")

      with_path(bin) { _(executable.find("widget")).must_be_nil }
    end

    it "ignores a directory that shares the name" do
      bin = mkdirs(tmpdir, "bin", "bin/widget").first

      with_path(bin) { _(executable.find("widget")).must_be_nil }
    end

    it "returns nil when nothing matches" do
      with_path(tmpdir) { _(executable.find("widget")).must_be_nil }
    end

    it "survives empty PATH entries" do
      bin = mkdirs(tmpdir, "bin").first
      make_executable(bin, "widget")

      with_env({"PATH" => "::#{bin}::"}) { _(executable.find("widget")).must_equal File.join(bin, "widget") }
    end

    it "returns nil when PATH is unset" do
      with_env({"PATH" => nil}) { _(executable.find("widget")).must_be_nil }
    end
  end

  describe ".exist?" do
    it "is true when the command is on PATH" do
      bin = mkdirs(tmpdir, "bin").first
      make_executable(bin, "widget")

      with_path(bin) { _(executable.exist?("widget")).must_equal true }
    end

    it "is false otherwise" do
      with_path(tmpdir) { _(executable.exist?("widget")).must_equal false }
    end
  end
end
