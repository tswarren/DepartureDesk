class WebsiteNormalizer
  Result = Data.define(:url, :normalized_url, :normalized_host, :error)

  def self.call(url:)
    new(url:).call
  end

  def initialize(url:)
    @raw = url.to_s.strip
  end

  def call
    return failure("Enter a website URL.") if @raw.blank?
    return failure("Website URL cannot contain credentials.") if @raw.match?(%r{\A[a-z][a-z0-9+\-.]*://[^/\s]+@}i)
    return failure("Website URL cannot contain control characters or internal spaces.") if @raw.match?(/[[:cntrl:]]/) || @raw.match?(/\s/)

    uri = Addressable::URI.parse(with_scheme(@raw))
    return failure("Enter a valid website URL.") if uri.nil?

    scheme = uri.scheme.to_s.downcase
    return failure("Only HTTP and HTTPS websites are supported.") unless %w[http https].include?(scheme)
    return failure("Website URL cannot contain credentials.") if uri.user || uri.password

    host = uri.normalized_host.to_s.downcase.delete_suffix(".")
    return failure("Enter a website with a hostname.") if host.blank?

    uri.scheme = scheme
    uri.host = host
    uri.fragment = nil
    uri.port = nil if default_port?(scheme, uri.port)
    uri.path = "" if uri.path == "/"
    uri.query = uri.query.presence

    normalized = uri.normalize.to_s
    normalized = normalized.delete_suffix("/") if uri.path.to_s.empty? || uri.path == "/"

    Result.new(url: @raw, normalized_url: normalized, normalized_host: host, error: nil)
  rescue Addressable::URI::InvalidURIError
    failure("Enter a valid website URL.")
  end

  private

  def with_scheme(value)
    value.match?(%r{\A[a-z][a-z0-9+\-.]*://}i) ? value : "https://#{value}"
  end

  def default_port?(scheme, port)
    (scheme == "http" && port == 80) || (scheme == "https" && port == 443)
  end

  def failure(message)
    Result.new(url: @raw, normalized_url: nil, normalized_host: nil, error: message)
  end
end
