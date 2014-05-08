Feature: Backwards-compatible deprecated commands
  Background:
    * I have an omnibus project named "hamlet"

  Scenario: When "build project" is given
    * I run `omnibus build project hamlet`
    * the output should contain:
      """
      The interface for building a project has changed. Please use 'omnibus build hamlet' instead.
      """

  Scenario: When "build software" is given
    * I run `omnibus build software preparation`
    * the output should contain:
      """
      Building an individual software definitions is no longer supported!
      """
    * the exit status should not be 0

  Scenario: When --timestamp is given
    * I run `omnibus build hamlet --timestamp`
    * the output should contain:
      """
      The '--timestamp' option has been deprecated! Please use '--override append_timestamp:true' instead.
      """

  Scenario: When --no-timestamp is given
    * I run `omnibus build hamlet --no-timestamp`
    * the output should contain:
      """
      The '--no-timestamp' option has been deprecated! Please use '--override append_timestamp:false' instead.
      """

  Scenario: When "project PROJECT" is given
    * I run `omnibus project hamlet`
    * the output should contain:
      """
      The project generator has been renamed to 'omnibus new'. Please use 'omnibus new hamlet' instead.
      """
