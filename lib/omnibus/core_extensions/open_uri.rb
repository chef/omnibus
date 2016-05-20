require "open-uri"

module OpenURI
  class << self
    #
    # The is a bug in Ruby's implementation of OpenURI that prevents redirects
    # from HTTP -> HTTPS. That should totally be a valid redirect, so we
    # override that method here and call it a day.
    #
    # Note: this does NOT permit HTTPS -> HTTP redirects, as that would be a
    # major security hole in the fabric of space-time!
    #
    def default_redirectable?(uri1, uri2)
      a, b = uri1.scheme.downcase, uri2.scheme.downcase

      a == b || (a == "http" && b == "https")
    end
    alias_method :redirectable?, :default_redirectable?

    #
    # Permit all redirects.
    #
    # Note: this DOES permit HTTP -> HTTP redirects, and that is a major
    # security hole!
    #
    # @return [true]
    #
    def unsafe_redirectable?(uri1, uri2)
      a, b = uri1.scheme.downcase, uri2.scheme.downcase

      a == b || (a == "http" && b == "https") || (a == "https" && b == "http")
    end

    #
    # Override the default open_uri method to search for our custom option to
    # permit unsafe redirects.
    #
    # @example
    #   open('http://example.com', allow_unsafe_redirects: true)
    #
    alias_method :original_open_uri, :open_uri
    def open_uri(name, *rest, &block)
      options = rest.find { |arg| arg.is_a?(Hash) } || {}

      if options.delete(:allow_unsafe_redirects)
        class << self
          alias_method :redirectable?, :unsafe_redirectable?
        end
      end

      original_open_uri(name, *rest, &block)
    ensure
      class << self
        alias_method :redirectable?, :default_redirectable?
      end
    end
  end

  #
  # Force Kernel#open to always return a Tempfile. This works around the fact
  # that the OpenURI-provided Kernel#open returns a StringIO OR a Tempfile
  # instances depending on the size of the data being downloaded. In the case
  # of Omnibus we always want a Tempfile.
  #
  # @see http://winstonyw.com/2013/10/02/openuris_open_tempfile_and_stringio/
  #
  class Buffer
    remove_const :StringMax
    StringMax = 0
  end
end
