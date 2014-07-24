Feature: omnibus publish
  Scenario: Overriding publishing platform
    * I run `omnibus publish artifactory fake * --platform debian`
    * the output should contain:
      """
      Publishing platform has been overriden to 'debian'
      """
  Scenario: Overriding publishing platform version
    * I run `omnibus publish artifactory fake * --platform-version 7`
    * the output should contain:
      """
      Publishing platform version has been overriden to '7'
      """
