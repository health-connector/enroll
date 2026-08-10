#!/bin/bash
 
result=0

base="$( dirname "${BASH_SOURCE[0]}" )/.."

cd $base

root=`pwd -P`

for test_dir in `ls -1 $root/components/`; do
  echo $root/components/$test_dir
  cd $root/components/$test_dir
  bundle install
  bundle exec rspec --fail-fast
  ((result+=$?))
  if [ $result -ne 0 ]; then
    echo "ENGINE FAILED"
	  exit $result
  fi
done

cd $root
bundle exec rake parallel:spec[4]
