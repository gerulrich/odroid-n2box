#!/bin/bash

CACHE=$(dirname "$(readlink -f "$0")")/cache

function download() {
  local -n p=$1
  if [ ! -f "$CACHE/${p[filename]}" ]; then
     if [ ! -z "${p[url]}" ]; then
       wget -O "$CACHE/${p[filename]}" --progress=dot:mega "${p[url]}"
     fi
  fi
}

function extract_tarball() {
  local -n p=$1
  cp "$CACHE/${p[filename]}" "${p[tarball]}"
  tar --force-local -C "${p[name]}" -xf "${p[tarball]}" --strip-components=1 --exclude="debian"
}

function clean() {
  local package=$1
  rm -rf $(ls -A -I debian "$package" | awk -v dir="$package" '{print dir"/"$0}')
  packages=$(cat "$package/debian/control" | grep "Package:" | sed "s,Package: \(.*\),$package/debian/\1,")
  for pkg in $packages; do
    echo "remove $pkg folder"
    rm -rf $(echo $pkg)
  done
  if [ -d "$package/debian/tmp" ]; then rm -rf "$package/debian/tmp"; fi
  if [ -d "$package/debian/.debhelper" ]; then rm -rf "$package/debian/.debhelper"; fi
  find "$package" -name ".DS_Store" -exec rm {} \;
  find "$package" -name "*.substvars" -exec rm {} \;
  find "$package" -name "*.debhelper.log" -exec rm {} \;
  find "$package" -name "*.debhelper" -exec rm {} \;
  rm -rf "$package/debian/files"
  rm -rf "$package/debian/debhelper-build-stamp"
}

mkdir -p $CACHE
distribution=$(sed -n "s/^VERSION_CODENAME=//p" /etc/os-release)
package_name=""

while [[ "$#" -gt 0 ]]; do case $1 in
  -c|--clean) clean=1;;
  -b|--build) build=1;;
  -d|--download-source) download=1;;
  -p|--package) package_name=$2; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done


info=$(cat build.json | jq -r ".packages[] | select(.name == \"$package_name\")" | jq -s .)
count=$(echo $info | jq -s '.[] | length')

if [ $count -eq 0 ]; then
 echo "package $1 not exists"
 exit 1
fi

declare -A package
package[name]="$package_name"
package[version]="$(echo $info | jq -r '.[0] | .version')"
package[revision]="$(echo $info | jq -r '.[0] | .revision')"
package[url]="$(echo $info | jq -r '.[0] | .tarball')"
package[filename]="${package[name]}-${package[prefix]}${package[version]}.tar.gz"
package[tarball]="${package[name]}-${package[prefix]}${package[version]}.orig.tar.gz"
package[git_version]=$(echo $info | jq -r '.[0] | .git_version | select (.!=null)')

version=$(cat ${package[name]}/debian/changelog | head -1 | sed 's/.*(\(.*\)).*/\1/')
if [ "$version" != "${package[version]}-${package[revision]}" ]; then
    echo "version not match: $version | ${package[version]}-${package[revision]}"
    exit 1
fi

if [ ! -z $clean ]; then 
  clean ${package[name]}
fi


if [ ! -z $download ]; then
  if [ -f "$CACHE/${p[filename]}" ]; then 
    rm "$CACHE/${p[filename]}"
  fi
  download package
fi

if [ ! -z $build ]; then
  download package
  extract_tarball package
  cd "$package_name" && debuild --set-envvar GIT_VERSION=$git_version \
                             --set-envvar PACKAGEVERSION="${version}~${distribution}" \
                             -b -us -uc
fi

