Feature: omnibus publish
  Scenario: Providing platform mappings file
    * I have a platform mappings file named "platform_mappings.json"
    * I run `omnibus publish artifactory fake * --platform-mappings platform_mappings.json`
    * the output should contain:
      """
      Publishing will be performed using provided platform mappings.
      """
