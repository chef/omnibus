#
# Copyright 2015-2018 Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "open-uri" unless defined?(OpenURI)
require "ruby-progressbar"

module Omnibus
  module DownloadHelpers
    def self.included(base)
      base.send(:include, InstanceMethods)
    end

    module InstanceMethods
      private

      #
      # Downloads a from a given url to a given path using Ruby's
      # +OpenURI+ implementation.
      #
      # @param [String] from_url
      # @param [String] to_path
      # @param [Hash] options
      #   +options+ compatible with Ruby's +OpenURI+ implementation.
      #   You can also use special option +enable_progress_bar+ which will
      #   display a progress bar during download.
      #
      # @raise [SocketError]
      # @raise [Errno::ECONNREFUSED]
      # @raise [Errno::ECONNRESET]
      # @raise [Errno::ENETUNREACH]
      # @raise [Timeout::Error]
      # @raise [OpenURI::HTTPError]
      #
      # @return [void]
      #
      def download_file!(from_url, to_path, download_options = {})
        options = download_options.dup

        # :enable_progress_bar is a special option we handle.
        # by default we enable the progress bar.
        enable_progress_bar = options.delete(:enable_progress_bar)
        enable_progress_bar = true if enable_progress_bar.nil?

        options.merge!(download_headers)
        options[:read_timeout] = Omnibus::Config.fetcher_read_timeout

        fetcher_retries ||= Omnibus::Config.fetcher_retries

        reported_total = 0
        if enable_progress_bar
          progress_bar = ProgressBar.create(
            output: $stdout,
            format: "%e %B %p%% (%r KB/sec)",
            rate_scale: ->(rate) { rate / 1024 }
          )

          options[:content_length_proc] = ->(total) do
            reported_total = total
            progress_bar.total = total
          end
          options[:progress_proc] = ->(step) do
            downloaded_amount = reported_total ? [step, reported_total].min : step
            progress_bar.progress = downloaded_amount
          end
        end

        if RUBY_VERSION.to_f < 2.7
          file = open(from_url, options)
        else
          file = URI.open(from_url, options)
        end
        # This is a temporary file. Close and flush it before attempting to copy
        # it over.
        file.close
        FileUtils.cp(file.path, to_path)
        file.unlink
      rescue SocketError,
             Errno::ECONNREFUSED,
             Errno::ECONNRESET,
             Errno::ENETUNREACH,
             Timeout::Error,
             OpenURI::HTTPError => e
        if fetcher_retries != 0
          log.info(log_key) { "Retrying failed download due to #{e} (#{fetcher_retries} retries left)..." }
          fetcher_retries -= 1
          retry
        else
          log.error(log_key) { "Download failed - #{e.class}!" }
          raise
        end
      end

      #
      # The list of headers to pass to the download.
      #
      # @return [Hash]
      #
      def download_headers
        {}.tap do |h|
          # Alright kids, sit down while grandpa tells you a story. Back when the
          # Internet was just a series of tubes, and you had to "dial in" using
          # this thing called a "modem", ancient astronaunt theorists (computer
          # scientists) invented gzip to compress requests sent over said tubes
          # and make the Internet faster.
          #
          # Fast forward to the year of broadband - ungzipping these files was
          # tedious and hard, so Ruby and other client libraries decided to do it
          # for you:
          #
          #   https://github.com/ruby/ruby/blob/c49ae7/lib/net/http.rb#L1031-L1033
          #
          # Meanwhile, software manufacturers began automatically compressing
          # their software for distribution as a +.tar.gz+, publishing the
          # appropriate checksums accordingly.
          #
          # But consider... If a software manufacturer is publishing the checksum
          # for a gzipped tarball, and the client is automatically ungzipping its
          # responses, then checksums can (read: should) never match! Herein lies
          # the bug that took many hours away from the lives of a once-happy
          # developer.
          #
          # TL;DR - Do not let Ruby ungzip our file
          #
          h["Accept-Encoding"] = "identity"
        end
      end
    end
  end
end
