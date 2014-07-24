Feature: omnibus build
  Scenario: When the project does not exist
    * I have an omnibus project named "hamlet"
    * I run `omnibus build bacon`
    * the output should contain:
      """
      I could not find a project named `bacon' in any of the project locations:
      """
