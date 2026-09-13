# frozen_string_literal: true

module MermaidPreview
  # `command -v`, without the subshell.
  module Executable
    module_function

    # Lazy so the walk stops at the first hit, the way PATH lookup should.
    def find(name)
      search_path.lazy.map { File.join(it, name) }.find { runnable?(it) }
    end

    def exist?(name) = !find(name).nil?

    def find!(name, hint:)
      find(name) || fail(MissingDependencyError, "#{name} not found; #{hint}")
    end

    def runnable?(path) = File.file?(path) && File.executable?(path)

    def search_path = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).reject(&:empty?)
  end
end
