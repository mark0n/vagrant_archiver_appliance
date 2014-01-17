#!/bin/bash
librarian-puppet install

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
