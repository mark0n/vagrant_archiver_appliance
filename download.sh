#!/bin/bash
pushd files
if [ ! -f apache-tomcat-jdbc-1.1.0.1-bin.tar.gz ]; then
  wget http://people.apache.org/~fhanik/jdbc-pool/v1.1.0.1/apache-tomcat-jdbc-1.1.0.1-bin.tar.gz
fi
if [ ! -f archappl_v0.0.1_SNAPSHOT_19-November-2013T10-01-18.tar.gz ]; then
  wget http://downloads.sourceforge.net/project/epicsarchiverap/snapshots/archappl_v0.0.1_SNAPSHOT_19-November-2013T10-01-18.tar.gz
fi
if [ ! -f mysql-connector-java-5.1.27.tar.gz ]; then
  echo Please download mysql-connector-java-5.1.27.tar.gz from the Oracle website. Extract jar file and drop it into "files" directory.
  exit 1
fi
if [ ! -d pvmanager ]; then
  hg clone http://hg.code.sf.net/p/pvmanager/pvmanager
else
  pushd pvmanager
  hg update
  popd
fi
popd
echo All files downloaded successfully. You can run "vagrant up" now.
