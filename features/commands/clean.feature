Feature: omnibus clean
  Scenario: When a bad name is given
    * I run `omnibus clean hamlet`
    * the output should contain:
      """
      I could not find an Omnibus project named 'hamlet'!
      """
    * the exit status should not be 0

  Scenario: When the --purge option is given
    * I have an omnibus project named "hamlet"
    * I successfully run `omnibus clean hamlet --purge`
    * the output should contain "remove  local/build/hamlet"

  Scenario: When no options are given
    * I have an omnibus project named "hamlet"
    * I successfully run `omnibus clean hamlet`
    * the output should not contain:
      """
      remove  local/build/hamlet
      """
