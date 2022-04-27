#!/bin/sh

echo "BUILDING FOR HOMEBREW TAP"

VERSION="dev_version"
if [ "$1" != "" ]; then
  VERSION=$1
fi
perl -pi -e "s/VERSION_NUMBER_HERE/$1/" rtest

version_dir="rtest_"$VERSION
echo "creating compressed release file..."
echo "  $version_dir.tgz"
rm -rf $version_dir > /dev/null 2>&1
rm -rf "$version_dir.tgz" > /dev/null 2>&1
mkdir $version_dir
cp rtest $version_dir/

# compress it
tar -czf $version_dir.tgz $version_dir
rm -rf $version_dir

echo "here's your SHA for homebrew"
shasum -a 256 $version_dir.tgz

