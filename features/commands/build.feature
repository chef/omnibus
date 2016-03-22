Feature: omnibus build
  Background:
    Given I have an omnibus project named "hamlet"

  Scenario: When the project does not exist
    When I run `omnibus build bacon`

    Then the output should contain:
         """
         I could not find a project named `bacon' in any of the project locations:
         """
    And  the exit status should not be 0

# These scenarios don't work on appveyor due to no heat.exe/candle.exe/light.exe
#  Scenario: When the project has no software definitions
#    When I run `omnibus build hamlet`
#
#    Then it should pass with "[Project: hamlet] I | Building version manifest"
#    And  the file "output/version-manifest.json" should exist
#    And  the file "output/version-manifest.txt" should exist
#    And  the file "output/LICENSE" should exist
#    And  the directory "output/LICENSES" should exist
#
#  Scenario: When the project has a software definition
#    Given a file "config/software/ophelia.rb" with:
#          """
#          name "ophelia"
#          default_version "1.0.0"
#          build do
#            command "echo true > #{install_dir}/blah.txt"
#          end
#          """
#    And   I append to "config/projects/hamlet.rb" with "dependency 'ophelia'"
#
#    When  I run `omnibus build hamlet`
#
#    Then it should pass with "[Builder: ophelia] I | $ echo true"
#    And  the file "output/blah.txt" should contain "true"
#    And  the file "output/version-manifest.json" should exist
#    And  the file "output/version-manifest.txt" should exist
#    And  the file "output/LICENSE" should exist
#    And  the directory "output/LICENSES" should exist
