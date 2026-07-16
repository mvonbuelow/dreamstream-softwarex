#!/usr/bin/env bash

set -e

mkdir -p workdir
cd workdir

# Common width/frequency configurations
configs="
512 195312
256 390625
64 156250
8 125000
"

tx_sizes="1472 736 368 184 92"
rx_sizes="1472 736 368 184 92"

# TX configurations
echo "rxtx,width,freq,packet_size,latency"
summary=""
for s in $tx_sizes; do
    printf '%s\n' "$configs" | while read -r w f; do
        [ -z "$w" ] && continue
        avg=$(openprj ../test.prj \
            -Dtop=tx_latency_tb \
            -Dwidth="$w" \
            -Dfreq="$f" \
            -Dnsamples=32 \
            -Dpacket_size="$s" 2>&1 | tee /dev/stderr | sed -n 's/^.*Average:[[:space:]]*\([0-9.]*\).*/\1/p')
        echo "tx,$w,$f,$s,$avg"
    done
done

# RX configurations
for s in $rx_sizes; do
    printf '%s\n' "$configs" | while read -r w f; do
        [ -z "$w" ] && continue
        avg=$(openprj ../test.prj \
            -Dtop=rx_latency_tb \
            -Dwidth="$w" \
            -Dfreq="$f" \
            -Dnsamples=32 \
            -Dpacket_size="$s" 2>&1 | tee /dev/stderr | sed -n 's/^.*Average:[[:space:]]*\([0-9.]*\).*/\1/p')
        echo "rx,$w,$f,$s,$avg"
    done
done

cd ..
