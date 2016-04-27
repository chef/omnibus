Feature: omnibus manifest
  Background:
    Given I have an omnibus project named "hamlet"

  Scenario: When the project does not exist
    When I run `omnibus manifest bacon`

    Then the output should contain:
         """
         I could not find a project named `bacon' in any of the project locations:
         """
    And  the exit status should not be 0

  Scenario: When the project has no software definitions
    When I run `omnibus manifest hamlet`

    Then it should pass with "[Project: hamlet] I | "

    And the output should match /^[Project: hamlet] I | \d\d\d\d-[0-1]\d-[0-3]\dT[0-2]\d:[0-6]\d:[0-6]\d(\+|\-)\d\d:\d\d | Building version manifest$/

    And  the output should contain:
         """
           "software": {

           },
         """

  Scenario: When the project has a software definition
    Given a file "config/software/ophelia.rb" with:
          """
          name "ophelia"
          default_version "1.0.0"
          build do
            command "echo true > #{install_dir}/blah.txt"
          end
          """
    And   I append to "config/projects/hamlet.rb" with "dependency 'ophelia'"

    When  I run `omnibus manifest hamlet`

    Then it should pass with "[Project: hamlet] I | "

    And the output should match /^[Project: hamlet] I | \d\d\d\d-[0-1]\d-[0-3]\dT[0-2]\d:[0-6]\d:[0-6]\d(\+|\-)\d\d:\d\d | Building version manifest$/
    And  the output should contain:
         """
           "software": {
             "ophelia": {
               "locked_version": "1.0.0",
               "locked_source": null,
               "source_type": "project_local",
               "described_version": "1.0.0",
               "license": "Unspecified"
             }
           },
         """

  Scenario: When the project has a software definition
    Given a file "config/software/ophelia.rb" with:
          """
          name "ophelia"
          default_version "1.0.0"
          build do
            command "echo true > #{install_dir}/blah.txt"
          end
          """
    And   I append to "config/projects/hamlet.rb" with "dependency 'ophelia'"

    When  I run `omnibus manifest hamlet`

    Then it should pass with "[Project: hamlet] I | "

    And the output should match /^[Project: hamlet] I | \d\d\d\d-[0-1]\d-[0-3]\dT[0-2]\d:[0-6]\d:[0-6]\d(\+|\-)\d\d:\d\d | Building version manifest$/

    And  the output should contain:
         """
           "software": {
             "ophelia": {
               "locked_version": "1.0.0",
               "locked_source": null,
               "source_type": "project_local",
               "described_version": "1.0.0",
               "license": "Unspecified"
             }
           },
         """
    And  the exit status should be 0

  Scenario: When the project has a software definition whose version depends on the OS
    Given a file "config/software/ophelia.rb" with:
          """
          name "ophelia"
          default_version (windows? ? "2.0.0" : "1.0.0")
          build do
            command "echo true > #{install_dir}/blah.txt"
          end
          """
    And   I append to "config/projects/hamlet.rb" with "dependency 'ophelia'"

    When  I run `omnibus manifest hamlet --os=linux --platform_family=debian --platform=ubuntu --platform_version=14.04`

    Then it should pass with "[Project: hamlet] I "

    And the output should match /^[Project: hamlet] I | \d\d\d\d-[0-1]\d-[0-3]\dT[0-2]\d:[0-6]\d:[0-6]\d(\+|\-)\d\d:\d\d | Building version manifest$/

    And  the output should contain:
         """
           "software": {
             "ophelia": {
               "locked_version": "1.0.0",
               "locked_source": null,
               "source_type": "project_local",
               "described_version": "1.0.0",
               "license": "Unspecified"
             }
           },
         """

  Scenario: When the project has a software definition whose version depends on the OS
    Given a file "config/software/ophelia.rb" with:
          """
          name "ophelia"
          default_version (windows? ? "2.0.0" : "1.0.0")
          build do
            command "echo true > #{install_dir}/blah.txt"
          end
          """
    And   I append to "config/projects/hamlet.rb" with "dependency 'ophelia'"

    When  I run `omnibus manifest hamlet --os=windows --platform_family=windows --platform=windows --platform_version=2012r2`

    Then it should pass with "[Project: hamlet] I | "

    And the output should match /^[Project: hamlet] I | \d\d\d\d-[0-1]\d-[0-3]\dT[0-2]\d:[0-6]\d:[0-6]\d(\+|\-)\d\d:\d\d | Building version manifest$/

    And  the output should contain:
         """
           "software": {
             "ophelia": {
               "locked_version": "2.0.0",
               "locked_source": null,
               "source_type": "project_local",
               "described_version": "2.0.0",
               "license": "Unspecified"
             }
           },
         """
