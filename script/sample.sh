#!/bin/sh

pod_simple=$(cat <<EOF
Pod::Simple::LinkSection
Pod::Simple::Checker
Pod::Simple::TiedOutFH
Pod::Simple::Text
Pod::Simple::Methody
Pod::Simple::DumpAsXML
Pod::Simple::PullParser
Pod::Simple::BlackBox
Pod::Simple::TranscodeDumb
Pod::Simple::DumpAsText
Pod::Simple::TranscodeSmart
Pod::Simple::XHTML
Pod::Simple::RTF
Pod::Simple::PullParserTextToken
Pod::Simple::XMLOutStream
Pod::Simple::SimpleTree
Pod::Simple::Transcode
Pod::Simple::PullParserStartToken
Pod::Simple::Progress
Pod::Simple::PullParserEndToken
Pod::Simple::Debug
Pod::Simple::HTML
Pod::Simple::Search
Pod::Simple::Subclassing
Pod::Simple::PullParserToken
Pod::Simple::HTMLBatch
Pod::Simple::TextContent
Pod::Simple::HTMLLegacy
Pod::Simple
EOF
)

PERLDOC=
PERL5LIB=$PERL5LIB:lib

for pod in $pod_simple
do
    output=tmp/$(echo $pod |sed 's/::/\//g').pod
    mkdir -p $(dirname $output)
    echo perldoc -L EN -o JA $pod
    temp=$(mktemp /tmp/podXXXXX)
    perldoc -L EN -o JA $pod > $temp
    mv $temp $output
done
