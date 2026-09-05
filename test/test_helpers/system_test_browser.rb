module SystemTestBrowser
  BROWSER_BINARIES = %w[
    google-chrome
    google-chrome-stable
    chromium
    chromium-browser
  ].freeze

  module_function

  def available?
    return true if ENV["GITHUB_ACTIONS"] == "true"
    return true if ENV["FORCE_SYSTEM_TESTS"] == "1"

    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |directory|
      BROWSER_BINARIES.any? do |binary|
        File.executable?(File.join(directory, binary))
      end
    end
  end
end
