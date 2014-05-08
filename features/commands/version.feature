Feature: omnibus version
  Scenario: When the -v flag is specified
    * I successfully run `omnibus -v`
    * the output should match /^Omnibus v(.+)$/

  Scenario: When the --version flag is specified
    * I successfully run `omnibus --version`
    * the output should match /^Omnibus v(.+)$/

  Scenario: When the version command is given
    * I successfully run `omnibus version`
    * the output should match /^Omnibus v(.+)$/
