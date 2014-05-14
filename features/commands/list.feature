Feature: omnibus list
  Scenario: When there are Omnibus projects
    * I have an omnibus project named "hamlet"
    * I successfully run `omnibus list`
    * the output should contain:
      """
      Omnibus projects:
        * hamlet (1.0.0)
      """

  Scenario: When there are no Omnibus projects
    * I successfully run `omnibus list`
    * the output should contain:
      """
      There are no Omnibus projects!
      """
