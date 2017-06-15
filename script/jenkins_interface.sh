#!/bin/bash -e
# -e dies on any program failure
#
# IN THIS FILE
#
# This is the Jenkins interfacing script to Ansbile Torpor and our Ansible central controller
#
# EXAMPLES
#
#  ## Runs the ks-test-harness.pl --git -test suite in the chosen Koha CI container, eg. koha_ci_1
#  jenkins_interface.sh git koha_ci_1
#
#    Asks Ansbile Torpor to execute the koha get-test suite via Ansible's Koha-role.
#    Ansible playbook makes /koha_ci_1/testResults.tar.gz downloadable for the last test run
#    Returns the Ansible playbook log
#    Checks if it succeeded
#    Downloads the test deliverables
#    Extracts them and makes sure everything looks fine.
#    Echoes the test log to Jenkins
#
#  ## Builds the given Koha CI container using ansible playbooks
#  jenkins_interface.sh build koha_ci_1
#
#    Asks Ansbile Torpor to build the given CI Koha via Ansible's Koha-role.
#    Returns the Ansible playbook log
#    Checks if it succeeded
#    Echoes the build log to Jenkins
#


testSuite=$1
inventory_hostname=$2
testResultsArchive="testResults.tar.gz"


#############################
## Exception handlers here ##
#############################

function exceptionAnsiblePlaybookCrashed {
  buildLog=$1
  msg="Ansible playbook crashed. Couldn't get the PLAY RECAP"
  exitCode=1
  exceptionAndExit "$buildLog" "$msg" "$exitCode"
}
function exceptionAnsiblePlaybookFailed {
  buildLog=$1
  msg="Ansible playbook failed"
  exitCode=1
  exceptionAndExit "$buildLog" "$msg" "$exitCode"
}
function exceptionAnsibleTestsCrashed {
  buildLog=$1
  msg="Ansible tests crashed"
  exitCode=1
  exceptionAndExit "$buildLog" "$msg" "$exitCode"
}
function exceptionNoTestResults {
  buildLog=$1
  msg="No test results! 'testResults' dir not present."
  exitCode=1
  exceptionAndExit "$buildLog" "$msg" "$exitCode"
}
function exceptionMissingJunitDir {
  buildLog=$1
  msg="Missing JUnit test results dir?"
  exitCode=1
  exceptionAndExit "$buildLog" "$msg" "$exitCode"
}
function exceptionMissingCloverDir {
  buildLog=$1
  msg="Missing Clover test coverage report dir?"
  exitCode=1
  exceptionAndExit "$buildLog" "$msg" "$exitCode"
}
function exceptionMissingJunitDeliverables {
  buildLog=$1
  msg="Missing Junit test reports. Probably because no tests were ran."
  exitCode=1
  exceptionAndExit "$buildLog" "$msg" "$exitCode"
}
function exceptionMissingCloverDeliverables {
  buildLog=$1
  msg="Missing Clover coverage reports. Probably because no tests were ran."
  exitCode=1
  exceptionAndExit "$buildLog" "$msg" "$exitCode"
}
function exceptionAndExit {
  buildLog=$1
  msg=$2
  exitCode=$3

  (>&2 echo "--------------------------------------------------------------")
  (>&2 echo "----------------!ANSBILE TORPOR TEST FAILED!------------------")
  (>&2 echo "--------------------BUILD LOG---------------------------------")
  (>&2 echo "$buildLog")
  (>&2 echo "---------------------MESSAGE----------------------------------")
  (>&2 echo "$msg")
  (>&2 echo "----------------END OF ANSBILE TORPOR TEST LOG----------------")
  (>&2 echo "--------------------------------------------------------------")

  exit $exitCode
}

############################
## Generic functions here ##
############################

function ansiblePlaybookOk {
  ansibleLog="$1"
  #Look if we got the proper Ansible end summary
  recapLog=$(echo "$ansibleLog" | grep -P -A5 '^PLAY RECAP \*\*\*\*\*\*\*\*')
  test -z "$recapLog" && exceptionAnsiblePlaybookCrashed "$ansibleLog"

  #Are there failed or unreachable steps?
  failure=$(echo "$recapLog" | grep -P '(unreachable=[123456789])|(failed=[123456789])')
  test -n "$failure" && exceptionAnsiblePlaybookFailed "$ansibleLog"
}


################
## Build Koha ##
################

if [ "$testSuite" == "build" ]
then
  ansibleLog=$(curl --silent --show-error 10.0.3.1:8079/koha/${testSuite}/${inventory_hostname})
  #Save the build log for further inspection if we crash
  echo "$ansibleLog" > ansibleLog

  ansiblePlaybookOk "$ansibleLog"

  #Nice. We won!!
  #Loudly echo the build log
  echo "$ansibleLog"
  exit 0
fi

###############
## Test Koha ##
###############

### Run the tests via AnsbileTorpor -> Ansible -> Koha
### Receive an archive of test deliverables or error text

## Run the tests
ansibleLog=$(curl --silent --show-error 10.0.3.1:8079/koha/${testSuite}test/${inventory_hostname})
#Save the build log for further inspection if we crash
echo "$ansibleLog" > ansibleLog

ansiblePlaybookOk "$ansibleLog"

## Receive test deliverables
curl --silent --show-error 10.0.3.1:8079/${inventory_hostname}/testResults.tar.gz > $testResultsArchive
#If what we received is not a .tar-archive, it is an error
if ! tar --test-label -f $testResultsArchive
then
  testLog=$(cat "$testResultsArchive")
  exceptionAnsibleTestsCrashed "$testLog"
fi



tar -xzf $testResultsArchive

[ ! -d "testResults" ] &&                exceptionNoTestResults
[ ! -d "testResults/junit" ] &&          exceptionMissingJunitDir
[ -z "$(ls -A testResults/junit/)" ] &&  exceptionMissingJunitDeliverables
[ ! -d "testResults/clover" ] &&         exceptionMissingCloverDir
[ -z "$(ls -A testResults/clover/)" ] && exceptionMissingCloverDeliverables

#Nice. We won!!
#Loudly echo the test log
echo "$ansibleLog"
exit 0


