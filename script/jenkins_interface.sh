testSuite=$1
inventory_hostname=$2
testResultsArchive="testResults.tar.gz"


if [ "$testSuite" == "build" ]
then
  #Loudly echo curl results, the build log
  curl --silent --show-error 10.0.3.1:8080/koha/${testSuite}/${inventory_hostname}
  exit 0
fi


#Run the tests via AnsbileTorpor -> Ansible -> Koha
#Receive an archive of test deliverables or error text
curl --silent --show-error 10.0.3.1:8080/koha/${testSuite}test/${inventory_hostname} > $testResultsArchive

#If what we received is not a .tar-archive, it is an error
if ! tar --test-label -f $testResultsArchive
then
  echo $testResultsArchive
  exit 1
fi

tar -xzf testResults.tar.gz

test ! -d junit && echo "junit dir not present?"
test ! -d clover && echo "clover dir not present?"

exit 0


