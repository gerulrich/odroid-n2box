#!/bin/bash
set -e
CACHE=$(dirname "$(readlink -f "$0")")/cache

function download() {
  local -n pkg=$1
  if [ ! -f "$CACHE/${pkg[filename]}" ]; then
     if [ ! -z "${pkg[url]}" ]; then
       wget -O "$CACHE/${pkg[filename]}" --progress=dot:mega "${pkg[url]}"
     fi
     if [ ! -z "${pkg[files]}" ]; then
	# extract tar in pkg name folder and remove.
	mkdir -p "$CACHE/${pkg[name]}" && tar -C "$CACHE/${pkg[name]}" --strip-components=1 -xf "$CACHE/${pkg[filename]}"
	rm "$CACHE/${pkg[filename]}"
        # download all file dependencies in "location folder", extract and remove tar.
	files=$(echo "${pkg[files]}" | jq -s '.[] | length')
        files=$((files-1))
        for idx in $(seq 0 $files); do
          location=$CACHE/${pkg[name]}/$(echo ${pkg[files]} | jq -r ".[$idx].location")
          file_name=$location/$(echo ${pkg[files]} | jq -r ".[$idx].name")
	  mkdir -p "$location" && wget -O "$file_name" --progress=dot:mega $(echo ${pkg[files]} | jq -r ".[$idx].url")
          tar -C "$location" --strip-components=1 -xf "$file_name"
          rm -rf "$file_name"
        done
	# create tar with all dependencies inside. Remove pkg folder name.
	tar -zcf "$CACHE/${pkg[filename]}" -C "$CACHE" "${pkg[name]}"
	rm -r "$CACHE/${pkg[name]}"
     fi
  fi
}

function extract_tarball() {
  local -n p=$1
  if [ ! -L "${p[directory]}/${p[tarball]}" ]; then
     ln -s "$CACHE/${p[filename]}" "${p[directory]}/${p[tarball]}"
  fi
  tar --force-local -C "${p[directory]}/${p[name]}" -xf "${package[directory]}/${p[tarball]}" --strip-components=1 --exclude="debian"
}

function clean() {
  local directory=$1
  local package=$2
  rm -rf $(ls -A -I debian "$directory/$package" | awk -v dir="$directory/$package" '{print dir"/"$0}')
  packages=$(cat "$directory/$package/debian/control" | grep "Package:" | sed "s,Package: \(.*\),$directory/$package/debian/\1,")
  for pkg in $packages; do
    echo "remove $pkg folder"
    rm -rf $(echo $pkg)
  done
  if [ -d "$directory/$package/debian/tmp" ]; then rm -rf "$package/debian/tmp"; fi
  if [ -d "$directory/$package/debian/.debhelper" ]; then rm -rf "$package/debian/.debhelper"; fi
  find "$directory/$package" -name ".DS_Store" -exec rm {} \;
  find "$directory/$package" -name "*.substvars" -exec rm {} \;
  find "$directory/$package" -name "*.debhelper.log" -exec rm {} \;
  rm -rf "$directory/$package/debian/files"
  rm -rf "$directory/$package/debian/debhelper-build-stamp"
  if [ -f "$directory/$package/debian/clean" ]; then
	  rm -rf $(cat "$directory/$package/debian/clean" | awk -v dir="$directory/$package" '{print dir"/"$0}')
  fi
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


info=$(cat packages.json | jq -r ".packages[] | select(.name == \"$package_name\")" | jq -s .)
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
package[directory]=$(echo $info | jq -r '.[0] | .group | select (.!=null)' | sed 's/,/\//g')
package[files]=$(echo $info | jq -r '.[0].files | select (.!=null)')

if [ -z "${package[directory]}" ]; then package[directory]="."; fi

version=$(cat ${package[directory]}/${package[name]}/debian/changelog | head -1 | sed 's/.*(\(.*\)).*/\1/')
if [ "$version" != "${package[version]}-${package[revision]}" ]; then
    echo "version not match: $version | ${package[version]}-${package[revision]}"
    exit 1
fi

if [ ! -z $clean ]; then 
  clean "${package[directory]}" "${package[name]}"
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
  wd=$(pwd)
  cd "${package[directory]}/$package_name" && debuild --set-envvar GIT_VERSION=$git_version \
                             --set-envvar PACKAGEVERSION="${version}~${distribution}" \
                             -b -us -uc
  mv "$wd/${package[directory]}/"*.deb $wd
fi

