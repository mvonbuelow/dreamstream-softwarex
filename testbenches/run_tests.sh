#!/usr/bin/env sh
mkdir workdir -p
for i in $(ls *.vhd); do
  cd workdir
  openprj ../test.prj -Dtop=${i%.vhd}
  cd ..
done
cd workdir
openprj ../test.prj -Dtop=tx_ipv4_tb -Dwidth=8
openprj ../test.prj -Dtop=tx_ipv4_tb -Dwidth=16
openprj ../test.prj -Dtop=tx_ipv4_tb -Dwidth=32
openprj ../test.prj -Dtop=tx_ipv4_tb -Dwidth=128
openprj ../test.prj -Dtop=tx_ipv4_tb -Dwidth=256
openprj ../test.prj -Dtop=tx_ipv4_tb -Dwidth=512
cd ..
