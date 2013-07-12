module Omnibus

  class InvalidS3Configuration < RuntimeError
    def initialize(s3_bucket, s3_access_key, s3_secret_key)
      @s3_bucket, @s3_access_key, @s3_secret_key = s3_bucket, s3_access_key, s3_secret_key
    end

    def to_s
      """
      One or more required S3 configuration values is missing.

      Your effective configuration was the following:

          s3_bucket     => #{@s3_bucket.inspect}
          s3_access_key => #{@s3_access_key.inspect}
          s3_secret_key => #{@s3_secret_key.inspect}

      If you truly do want S3 caching, you should add values similar
      to the following in your Omnibus config file:

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

  class NoPackageFile < RuntimeError
    def initialize(package_path)
      @package_path = package_path
    end

    def to_s
      """
      Cannot locate or access the package at the given path:

        #{@package_path}
      """
    end
  end

  class NoPackageMetadataFile < RuntimeError
    def initialize(package_metadata_path)
      @package_metadata_path = package_metadata_path
    end

    def to_s
      """
      Cannot locate or access the package metadata file at the given path:

        #{@package_metadata_path}
      """
    end
  end

  class InvalidS3ReleaseConfiguration < RuntimeError
    def initialize(s3_bucket, s3_access_key, s3_secret_key)
      @s3_bucket, @s3_access_key, @s3_secret_key = s3_bucket, s3_access_key, s3_secret_key
    end

    def to_s
      """
      One or more required S3 configuration values is missing.

      Your effective configuration was the following:

          release_s3_bucket     => #{@s3_bucket.inspect}
          release_s3_access_key => #{@s3_access_key.inspect}
          release_s3_secret_key => #{@s3_secret_key.inspect}

      To release a package to S3, add the following values to your
      config file:

          release_s3_bucket      ENV['S3_BUCKET_NAME']
          release_s3_access_key  ENV['S3_ACCESS_KEY']
          release_s3_secret_key  ENV['S3_SECRET_KEY']

      Note that you are not required to use environment variables as
      illustrated (and the ones listed have no special significance in
      Omnibus), but it is encouraged to prevent spread of sensitive
      information and inadvertent check-in of same to version control
      systems.

      """
    end
  end
  # Raise this error if a needed Project configuration value has not
  # been set.
  class MissingProjectConfiguration < RuntimeError
    def initialize(parameter_name, sample_value)
      @parameter_name, @sample_value = parameter_name, sample_value
    end

    def to_s
      """
      You are attempting to build a project, but have not specified
      a value for '#{@parameter_name}'!

      Please add code similar to the following to your project DSL file:

         #{@parameter_name} '#{@sample_value}'

      """
    end
  end

  class MissingPatch < RuntimeError
    def initialize(patch_name, search_paths)
      @patch_name, @search_paths = patch_name, search_paths
    end

    def to_s
      """
      Attempting to apply the patch #{@patch_name}, but it was not
      found at any of the following locations:

      #{@search_paths.join("\n      ")}
      """
    end
  end

  class MissingProjectDependency < RuntimeError
    def initialize(dep_name, search_paths)
      @dep_name, @search_paths = dep_name, search_paths
    end

    def to_s
      """
      Attempting to load the project dependency '#{@dep_name}', but it was
      not found at any of the following locations:

      #{@search_paths.join("\n      ")}
      """
    end
  end
end
