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

./sample/perldoc-ja.sh $pod_simple
