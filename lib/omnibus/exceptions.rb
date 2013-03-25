module Omnibus

  class NoConfiguration < RuntimeError
    def to_s
      """
      Omnibus has not been configured yet!

      Please add a block like the following to your project's
      Rakefile:

          Omnibus.configure do |config|
            config.install_dir = '/path/to/install_dir'
            ...
          end


      See the documentation for Omnibus::Config for available options.
      """
    end
  end

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

      If you truly do want S3 caching, you can use a configuration
      block similar to this in your Rakefile:

          Omnibus.configure do |config|
            ...
            config.use_s3_caching = true
            config.s3_bucket      = 'my_bucket_name'
            config.s3_access_key  = MY_ACCESS_KEY
            config.s3_secret_key  = MY_SECRET_KEY
            ...
          end

      """
    end
  end

end
