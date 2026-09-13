# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "mermaid_preview"

require "fileutils"
require "minitest/autorun"
require "minitest/mock"
require "stringio"
require "tmpdir"

# Stands in for a Process::Status, which can't be built by hand.
FakeStatus = Data.define(:ok) do
  def success? = ok
end

# An IO that claims to be a terminal, for the colour branch in Reporter.
class TtyIO < StringIO
  def tty? = true
end

module TestHelpers
  def in_tmpdir(&) = Dir.mktmpdir("mmd-preview-test", &)

  # A scratch dir that lives for one `it`, torn down by the after hook below.
  def tmpdir
    @tmpdir ||= Dir.mktmpdir("mmd-preview-test")
  end

  def write_file(name, contents = "", dir: tmpdir)
    File.join(dir, name).tap { |path| File.write(path, contents) }
  end

  def make_executable(dir, name)
    File.join(dir, name).tap do |path|
      File.write(path, "#!/bin/sh\nexit 0\n")
      FileUtils.chmod(0o755, path)
    end
  end

  def mkdirs(root, *names)
    names.map { |name| File.join(root, name).tap { |dir| FileUtils.mkdir_p(dir) } }
  end

  def with_env(values)
    original = values.keys.to_h { |key| [key, ENV[key]] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    original.each { |key, value| ENV[key] = value }
  end

  def with_path(*dirs, &) = with_env({"PATH" => dirs.join(File::PATH_SEPARATOR)}, &)
end

module Minitest
  class Spec
    include TestHelpers

    after { FileUtils.remove_entry(@tmpdir) if @tmpdir && File.directory?(@tmpdir) }
  end
end
