#!/bin/bash

archive="nwchem-6.8-release.revision-v6.8-47-gdf6c956-src.2017-12-14.tar.bz2"
CDM="wget https://github.com/nwchemgit/nwchem/releases/download/v6.8-release/${archive}"
echo ${CMD}
${CDM} || exit 10

echo "tar jxf $archive"
tar jxf $archive

