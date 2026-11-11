require "open3"

# Renders an issued document's snapshot to PDF with headless Chromium's
# command line (ADR 0019; step 10 plan, question 6). The page is
# self-contained, so nothing is fetched while rendering. The template and
# renderer versions are stored with each version, to explain how its file
# was produced.
class DocumentRenderer
  # Bump when the template's output changes.
  TEMPLATE_VERSION = "2026-11-10.1"
  BINARIES = %w[chromium chromium-browser google-chrome google-chrome-stable].freeze
  TIMEOUT_SECONDS = 60

  Rendered = Data.define(:pdf, :sha256, :template_version, :renderer_version)

  class Error < StandardError; end

  def self.binary
    @binary ||= ENV["DOCUMENT_CHROMIUM_PATH"].presence ||
      BINARIES.find { |name| ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, name)) } } ||
      raise(Error, "Chromium isn't installed, so documents can't be rendered.")
  end

  def self.renderer_version
    @renderer_version ||= begin
      output, status = Open3.capture2e(binary, "--version")
      status.success? ? output.strip.lines.last.to_s.strip : "unknown"
    end
  end

  def self.html(snapshot, logo: nil)
    ApplicationController.render(template: "documents/pdf", layout: false, locals: { snapshot:, logo_data_uri: logo_data_uri(logo) })
  end

  def self.render(snapshot, logo: nil)
    html = html(snapshot, logo:)
    Dir.mktmpdir("document") do |dir|
      page = File.join(dir, "document.html")
      pdf = File.join(dir, "document.pdf")
      File.write(page, html)
      output, status = Open3.capture2e(
        "timeout", TIMEOUT_SECONDS.to_s, binary, "--headless", "--no-sandbox", "--disable-gpu", "--disable-extensions",
        "--disable-background-networking", "--no-first-run", "--no-pdf-header-footer", "--user-data-dir=#{File.join(dir, "profile")}",
        "--print-to-pdf=#{pdf}", "file://#{page}"
      )
      raise Error, "The document could not be rendered: #{output.lines.last(3).join.strip}" unless status.success? && File.size?(pdf)

      bytes = File.binread(pdf)
      Rendered.new(pdf: bytes, sha256: Digest::SHA256.hexdigest(bytes), template_version: TEMPLATE_VERSION, renderer_version:)
    end
  end

  def self.logo_data_uri(logo)
    return unless logo&.attached?

    "data:#{logo.blob.content_type};base64,#{Base64.strict_encode64(logo.download)}"
  end
  private_class_method :logo_data_uri
end
