#!/usr/bin/env sh
mkdir workdir -p
for i in $(ls *.vhd); do
  cd workdir
  openprj ../test.prj -Dtop=${i%.vhd}
  cd ..
done
