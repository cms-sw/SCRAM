#!/bin/bash
this_dir=$(dirname $0)
arch=$(BUILD_ARCH= cmsos)
for var in `diff -u <(env | sort) <(source ${this_dir}/../${arch}/etc/profile.d/init.sh; env | sort) 2>&1 | grep '+[^ ]*=' | sed 's|=.*||;s|^+||'`; do
  eval export _SCRAM_SYSVAR_${var}="\$$var"  
done
. ${this_dir}/../${arch}/etc/profile.d/init.sh
${this_dir}/../${arch}/bin/scram.py $@

