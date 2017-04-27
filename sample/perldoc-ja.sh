#!/bin/sh

PERLDOC=
PERL5LIB=lib:$PERL5LIB

for pod in $*
do
    output=tmp/$(echo $pod |sed 's/::/\//g').pod
    mkdir -p $(dirname $output)
    echo perldoc -L EN -o JA $pod
    temp=$(mktemp /tmp/podXXXXX)
    perldoc -L EN -o JA $pod > $temp
    mv $temp $output
done
