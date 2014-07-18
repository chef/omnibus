require 'open-uri'

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
    def redirectable?(uri1, uri2)
      a, b = uri1.scheme.downcase, uri2.scheme.downcase

      a == b || (a == 'http' && b == 'https')
    end
  end
end
