Feature: omnibus publish
  Scenario: Providing platform mappings file
    * I have a platform mappings file named "platform_mappings.json"
    * I run `omnibus publish artifactory fake * --platform-mappings platform_mappings.json`
    * the output should contain:
      """
      Publishing will be performed using provided platform mappings.
      """

  Scenario: When a user provides the deprecated `--version-manifest` flag
    * I run `omnibus publish artifactory fake * --version-manifest /fake/path/version-manifest.json`
    * the output should contain:
      """
      The `--version-manifest' option has been deprecated. Version manifest data is now part of the `*.metadata.json' file
      """
