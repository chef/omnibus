module Omnibus

  class InvalidS3Configuration < RuntimeError
    def initialize(s3_bucket, s3_access_key, s3_secret_key)
      @s3_bucket, @s3_access_key, @s3_secret_key = s3_bucket, s3_access_key, s3_secret_key
    end

    def to_s
      """
      You indicated that you would like to use S3 caching by setting
      the `use_s3_caching` parameter to true

      However, this requires non-nil values for several other
      important parameters.

      Your effective configuration was the following:

          s3_bucket     => #{@s3_bucket.inspect}
          s3_access_key => #{@s3_access_key.inspect}
          s3_secret_key => #{@s3_secret_key.inspect}

      If you truly do want S3 caching, you should add values similar
      to the following in your Omnibus config file:

            use_s3_caching true
            s3_bucket      ENV['S3_BUCKET_NAME']
            s3_access_key  ENV['S3_ACCESS_KEY']
            s3_secret_key  ENV['S3_SECRET_KEY']

      Note that you are not required to use environment variables as
      illustrated (and the ones listed have no special significance in
      Omnibus), but it is encouraged to prevent spread of sensitive
      information and inadvertent check-in of same to version control
      systems.

      """
    end
  end

end
