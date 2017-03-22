require "ffi_yajl"

module Omnibus
  class Packager::PKGNG < Packager::Base
    # @return [Hash]
    SCRIPT_MAP = {
      # Default Omnibus naming
      preinst:  "pre-install",
      postinst: "post-install",
      inst:     "install",
      prerm:    "pre-deinstall",
      postrm:   "post-deinstall",
      rm:       "deinstall",
      preup:    "pre-upgrade",
      postup:   "post-upgrade",
      up:       "upgrade",
    }.freeze

    id :pkgng

    setup do
      # Copy the full-stack installer into staging_dir, accounting for
      # any excluded files.
      #
      # /opt/halmet => /tmp/daj29013/opt/hamlet
      destination = File.join(staging_dir, project.install_dir)
      FileSyncer.sync(project.install_dir, destination, exclude: exclusions)

      # Copy over any user-specified extra package files.
      #
      # Files retain their relative paths inside the scratch directory, so
      # we need to grab the dirname of the file, create that directory, and
      # then copy the file into that directory.
      #
      # extra_package_file '/path/to/foo.txt' #=> /tmp/daj29013/path/to/foo.txt
      project.extra_package_files.each do |file|
        parent      = File.dirname(file)
        destination = File.join(staging_dir, parent)

        create_directory(destination)
        copy_file(file, destination)
      end
    end

    build do
      write_compact_manifest
      write_manifest
      create_txz_file
    end

    #
    # @!group DSL methods
    # --------------------------------------------------

    #
    # Set or return the origin for this package.
    #
    # @example
    #   origin "www/apache22"
    #
    # @param [String] val
    #   the origin of this package
    #
    # @return [String]
    #   the origin of this package
    #
    def origin(val = NULL)
      if null?(val)
        @origin || "omnibus/#{safe_base_package_name}"
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:origin, "be a String")
        end

        @origin = val
      end
    end
    expose :origin

    #
    # Set or return the comment for this package
    #
    # @example
    #   comment "The full stack of project"
    #
    # @param [String] val
    #   a short comment that describes this package
    #
    # @return [String]
    #   the short comment that describes this package
    #
    def comment(val = NULL)
      if null?(val)
        @comment || safe_comment
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:comment, "be a String")
        end

        @comment = val
      end
    end
    expose :comment

    #
    # Set or return the prefix this package will install to
    #
    # @example
    #   prefix "/usr/local"
    #
    # @param [String] val
    #   a prefix path
    #
    # @return [String]
    #   the prefix path
    #
    def prefix(val = NULL)
      if null?(val)
        @prefix || "/"
      else
        unless val.is_a?(String)
          raise InvalidValue.new(:prefix, "be a String")
        end

        @prefix = val
      end
    end
    expose :prefix

    #
    # Set or return the licenses for this package.
    #
    # @example
    #   licenses ["Apache 2.0", "MIT"]
    #
    # @param [Array] val
    #   the licenses for this package
    #
    # @return [Array]
    #   the licenses for this package
    #
    def licenses(val = NULL)
      if null?(val)
        @licenses || [project.license]
      else
        unless val.is_a?(Array)
          raise InvalidValue.new(:licenses, "be an Array")
        end

        @licenses = val
      end
    end
    expose :licenses

    #
    # Set or return the categories for this package.
    #
    # @example
    #   categories ["databases"]
    #
    # @param [Array] val
    #   the categories for this package
    #
    # @return [Array]
    #   the categories for this package
    #
    def categories(val = NULL)
      if null?(val)
        @categories || ["misc"]
      else
        unless val.is_a?(Array)
          raise InvalidValue.new(:categories, "be an Array")
        end

        @categories = val
      end
    end
    expose :categories

    #
    # Set or return the users for this package.
    #
    # @example
    #   users ["root"]
    #
    # @param [Array] val
    #   the users for this package
    #
    # @return [Array]
    #   the users for this package
    #
    def users(val = NULL)
      if null?(val)
        @users || [project.package_user]
      else
        unless val.is_a?(Array)
          raise InvalidValue.new(:users, "be an Array")
        end

        @users = val
      end
    end
    expose :users

    #
    # Set or return the groups for this package.
    #
    # @example
    #   groups ["root"]
    #
    # @param [Array] val
    #   the groups for this package
    #
    # @return [Array]
    #   the groups for this package
    #
    def groups(val = NULL)
      if null?(val)
        @groups || [project.package_group]
      else
        unless val.is_a?(Array)
          raise InvalidValue.new(:groups, "be an Array")
        end

        @groups = val
      end
    end
    expose :groups

    #
    # Set or return the runtime dependencies for this package.
    #
    # @example
    #   runtime_dependencies {
    #     "libiconv" => {
    #       "origin" => "converters/libiconv",
    #       "version" => "1.13.1_2"
    #     }
    #   }
    #
    # @param [Hash] val
    #   the runtime dependencies for this package
    #
    # @return [Hash]
    #   the runtime dependencies for this package
    #
    def runtime_dependencies(val = NULL)
      if null?(val)
        @runtime_dependencies || {}
      else
        unless val.is_a?(Hash)
          raise InvalidValue.new(:runtime_dependencies, "be a Hash")
        end

        @runtime_dependencies = val
      end
    end
    expose :runtime_dependencies

    #
    # Set or return the options for this package.
    #
    # @example
    #   options {
    #     "OPT1" => "off"
    #   }
    #
    # @param [Hash] val
    #   the options for this package
    #
    # @return [Hash]
    #   the options for this package
    #
    def options(val = NULL)
      if null?(val)
        @options || {}
      else
        unless val.is_a?(Hash)
          raise InvalidValue.new(:options, "be a Hash")
        end

        @options = val
      end
    end
    expose :options

    #
    # @!endgroup
    # --------------------------------------------------

    #
    # The name of the package to create.
    #
    # @return [String]
    #
    def package_name
      "#{safe_base_package_name}-#{pkgng_version}.txz"
    end

    #
    # Read all scripts in {Project#package_scripts_path}
    #
    # @return [void]
    #
    def package_scripts
      SCRIPT_MAP.reduce({}) do |scripts, (source, destination)|
        source_path = File.join(project.package_scripts_path, source.to_s)

        if File.file?(source_path)
          log.debug(log_key) { "Adding script `#{source}'" }
          scripts[destination] = File.read(source_path)
        end

        scripts
      end
    end

    def compact_manifest
      {
        name: safe_base_package_name,
        version: pkgng_version,
        origin: origin,
        comment: comment,
        arch: safe_architecture,
        www: project.homepage,
        maintainer: safe_maintainer,
        prefix: prefix,
        licenses: licenses,
        flatsize: package_size,
        users: users,
        groups: groups,
        options: options,
        desc: project.description,
        categories: categories,
        deps: runtime_dependencies,
      }
    end

    def manifest
      {
        files: package_files,
        directories: {},
        scripts: package_scripts,
      }
    end

    #
    # Render a COMPACT_MANIFEST file in +#{staging_dir}/\+COMPACT_MANIFEST+
    #
    # @return [void]
    #
    def write_compact_manifest
      destination = File.join(staging_dir, "+COMPACT_MANIFEST")
      File.open(destination, "w+") do |f|
        FFI_Yajl::Encoder.encode(compact_manifest, pretty: true).each_line do |line|
          f.write(line)
        end
      end
    end

    #
    # Render a MANIFEST file in +#{staging_dir}/\+MANIFEST+
    #
    # @return [void]
    #
    def write_manifest
      destination = File.join(staging_dir, "+MANIFEST")
      File.open(destination, "w+") do |f|
        FFI_Yajl::Encoder.encode(compact_manifest.merge(manifest), pretty: true).each_line do |line|
          f.write(line)
        end
      end
    end

    #
    # Create the +.txz+ file, compressing at the default xz level of 6.
    # @return [void]
    #
    def create_txz_file
      log.info(log_key) { "Creating .txz file" }

      flags = []
      flags << "-v" # verbose output
      flags << "-f txz" # format, can be txz, tbz, tgz or tar
      flags << "-m #{staging_dir}" # metadata dir
      flags << "-r #{staging_dir}" # staging dir to use as root dir

      cmd = "pkg create #{flags.join(' ')} #{package_name}"

      # Execute the build command
      Dir.chdir(Config.package_dir) do
        shellout!(cmd)
      end
    end

    #
    # The size of this package. This is dynamically calculated.
    #
    # @return [Fixnum]
    #
    def package_size
      @package_size ||= begin
        path  = "#{project.install_dir}/**/*"
        total = FileSyncer.glob(path).reduce(0) do |size, path|
          unless File.directory?(path) || File.symlink?(path)
            size += File.size(path)
          end

          size
        end

        # size in bytes, divided by 1024 and rounded up.
        total / 1024
      end
    end

    #
    # Generate and return list of every file in the package,
    # with their respective sha256 sums
    #
    # @return [Hash]
    #
    def package_files
      path = "#{staging_dir}/**/*"
      exclude_files = [
        "+COMPACT_MANIFEST",
        "+MANIFEST",
      ]
      FileSyncer.glob(path).reduce({}) do |hash, path|
        if File.file?(path)
          relative_path = path.gsub("#{staging_dir}/", "")
          unless exclude_files.include?(relative_path)
            absolute_path = File.join("/", relative_path)
            hash[absolute_path] = digest(path, :sha256)
          end
        end

        hash
      end
    end

    #
    # Return the FreeBSD-ready base package name, converting any invalid characters to
    # dashes (+-+).
    #
    # @return [String]
    #
    def safe_base_package_name
      if project.package_name =~ /\A[a-z0-9\.\+\-]+\z/
        project.package_name.dup
      else
        converted = project.package_name.downcase.gsub(/[^a-z0-9\.\+\-]+/, "-")

        log.warn(log_key) do
          "The `name' component of FreeBSD package names can only include " \
          "lower case alphabetical characters (a-z), numbers (0-9), dots (.), " \
          "plus signs (+), and dashes (-). Converting `#{project.package_name}' to " \
          "`#{converted}'."
        end

        converted
      end
    end

    #
    # This is actually just the regular build_iteration, but it felt lonely
    # among all the other +safe_*+ methods.
    #
    # @return [String]
    #
    def safe_build_iteration
      project.build_iteration
    end

    #
    # Return the FreeBSD-ready version.
    #
    # See: https://www.freebsd.org/doc/en/books/porters-handbook/makefile-naming.html
    #
    # @return [String]
    #
    def safe_version
      version = project.build_version.dup

      if version =~ /\-/
        converted = version.tr("-", "_")

        log.warn(log_key) do
          "FreeBSD package versions cannot contain dashes or strings. " \
          "Converting `#{project.build_version}' to `#{converted}'."
        end

        version = converted
      end

      if version =~ /\A[a-zA-Z0-9\.\+\:\~]+\z/
        version
      else
        converted = version.gsub(/[^a-zA-Z0-9\.\+\:\~]+/, "_")

        log.warn(log_key) do
          "The `version' component of FreeBSD package names can only include " \
          "alphabetical characters (a-z, A-Z), numbers (0-9), dots (.), " \
          "plus signs (+), dashes (-), tildes (~) and colons (:). Converting " \
          "`#{project.build_version}' to `#{converted}'."
        end

        converted
      end
    end

    #
    # A pkgng-compatible version including the build iteration
    #
    # @return [String]
    #
    def pkgng_version
      "#{safe_version}_#{safe_build_iteration}"
    end

    #
    # The architecture for this package.
    #
    # @return [String]
    #
    def safe_architecture
      case Ohai["kernel"]["machine"]
      when "i686"
        "i386"
      else
        Ohai["kernel"]["machine"]
      end
    end

    #
    # Returns a FreeBSD-ready comment.
    #
    # Rules:
    # 1. The COMMENT string should be 70 characters or less.
    # 2. Do not include the package name or version number of software.
    # 3. The comment must begin with a capital and end without a period.
    # 4. Do not start with an indefinite article (that is, A or An).
    # 5. Capitalize names such as Apache, JavaScript, or Perl.
    # 6. Use a serial comma for lists of words: "green, red, and blue."
    # 7. Check for spelling errors.
    #
    # @return [String]
    #
    def safe_comment
      description = project.description.dup

      if description.length > 70
        description[0..69]
      else
        description
      end
    end

    #
    # Returns a FreeBSD-ready maintainer. Only a single address without the
    # comment part is allowed as a MAINTAINER value. The format used is
    # user@hostname.domain. Please do not include any descriptive text
    # such as a real name in this entry.
    #
    # @return [String]
    #
    def safe_maintainer
      project.maintainer
    end
  end
end
