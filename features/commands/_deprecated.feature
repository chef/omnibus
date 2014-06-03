Feature: Backwards-compatible deprecated commands
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
      Building individual software definitions is no longer supported!
      """
    * the exit status should not be 0

  Scenario: When --timestamp is given
    * I run `omnibus build hamlet --timestamp`
    * the output should contain:
      """
      The '--timestamp' option has been deprecated! Please use '--override append_timestamp:true' instead.
      """

  Scenario: When -t is given
    * I run `omnibus build hamlet -t`
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
      The project generator has been renamed to 'omnibus new'. Please use 'omnibus new' in the future.
      """

  Scenario: When OMNIBUS_APPEND_TIMESTAMP is given (true)
    * I set the environment variables to:
      | variable                 | value |
      | OMNIBUS_APPEND_TIMESTAMP | true  |
    * I run `omnibus build hamlet`
    * the output should contain:
      """
      The environment variable 'OMNIBUS_APPEND_TIMESTAMP' is deprecated. Please use '--override append_timestamp:true' instead.
      """

  Scenario: When OMNIBUS_APPEND_TIMESTAMP is given (false)
    * I set the environment variables to:
      | variable                 | value |
      | OMNIBUS_APPEND_TIMESTAMP | false  |
    * I run `omnibus build hamlet`
    * the output should contain:
      """
      The environment variable 'OMNIBUS_APPEND_TIMESTAMP' is deprecated. Please use '--override append_timestamp:false' instead.
      """

  Scenario: When "release package" is given
    * I run `omnibus release package /path/to/package`
    * the output should contain:
      """
      The interface for releasing a project has changed. Please use 'omnibus publish BACKEND [COMAMND]' instead.
      """

  Scenario: When "release package --public" is given
    * I run `omnibus release package /path/to/package --public`
    * the output should contain:
      """
      The '--public' option has been deprecated! Please use '--acl public' instead.
      """

  Scenario: When "release package --no-public" is given
    * I run `omnibus release package /path/to/package --no-public`
    * the output should contain:
      """
      The '--no-public' option has been deprecated! Please use '--acl private' instead.
      """
