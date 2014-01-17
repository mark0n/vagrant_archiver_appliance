#!/bin/bash
librarian-puppet install

pushd modules/archiver_appliance/files
if [ ! -f mysql-connector-java-5.1.27.tar.gz ]; then
  echo Please download mysql-connector-java-5.1.27.tar.gz from the Oracle website. Extract jar file and drop it into "files" directory.
  exit 1
fi
popd
pushd files
if [ ! -d pvmanager ]; then
  hg clone http://hg.code.sf.net/p/pvmanager/pvmanager
else
  pushd pvmanager
  hg update
  popd
fi
popd
echo All files downloaded successfully. You can run "vagrant up" now.
