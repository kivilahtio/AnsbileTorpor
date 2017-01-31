#!/bin/bash
#
# IN THIS FILE
#
# This is the Jenkins interfacing script to Ansbile Torpor and our Ansible central controller
#
# EXAMPLES
#
#  ## Runs the ks-test-harness.pl --git -test suite in the chosen Koha CI container inventory_hostname
#  jenkins_interface.sh git koha_ci_1
#
#  ## Builds the Koha CI container using ansible playbooks
#  jenkins_interface.sh build koha_ci_1
#
#


testSuite=$1
inventory_hostname=$2
testResultsArchive="testResults.tar.gz"


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
function exceptionAndExit {
  buildLog=$1
  msg=$2
  exitCode=$3

  echo "$buildLog"
  echo "-----------------------------------------------------"
  echo "$msg"
  exit $exitCode
}

if [ "$testSuite" == "build" ]
then
  buildLog=$(curl -# 10.0.3.1:8080/koha/${testSuite}/${inventory_hostname})
#  buildLog=$(cat buildlog)
  #Save the build log for further inspection if we crash
  echo "$buildLog" > buildlog

  #Look if we got the proper Ansible end summary
  recapLog=$(echo "$buildLog" | grep -P -A5 '^PLAY RECAP \*\*\*\*\*\*\*\*')
  test -z "$recapLog" && exceptionAnsiblePlaybookCrashed "$buildLog"

  #Are there failed or unreachable steps?
  failure=$(echo "$recapLog" | grep -P '(unreachable=[123456789])|(failed=[123456789])')
  test -n "$failure" && exceptionAnsiblePlaybookFailed "$buildLog"

  #Nice. We won!!
  #Loudly echo the build log
  echo "$buildLog"
  exit 0
fi

#Run the tests via AnsbileTorpor -> Ansible -> Koha
#Receive an archive of test deliverables or error text
curl --silent --show-error 10.0.3.1:8080/koha/${testSuite}test/${inventory_hostname} > $testResultsArchive

#If what we received is not a .tar-archive, it is an error
if ! tar --test-label -f $testResultsArchive
then
  testLog=$(cat "$testResultsArchive")
  exceptionAnsibleTestsCrashed "$testLog"
fi



tar -xzf testResults.tar.gz


[ ! -d "testResults" ] && echo "testResults dir not present?" && exit 1
[ ! -d "testResults/junit" ] && echo "junit dir not present?" && exit 1
[ ! -d "testResults/clover" ] && echo "clover dir not present?" && exit 1

exit 0


