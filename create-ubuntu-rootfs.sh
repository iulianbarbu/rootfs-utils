# Needs support for building arm rootfs on x86_64.
# See qemu-static: https://gnu-linux.org/building-ubuntu-rootfs-for-arm.html.

function help {
	echo "Usage: ./create-ubuntu-rootfs [params]"
	echo
	echo "Mandatory:"
	echo "-r release - Specify the release name (e.g '-r xenial')."
	echo "-v - The release version which will be downloaded (e.g '-v 16.04' - coresponds to 'xenial' release).'"
	echo "-s (digit+)(M(egabytes)|G(igabytes)) - Specify the size of the ext4 rootfs image. Minimal size is 200M."
	echo 
	echo "Optional:"
	echo "-o path - Rootfs image path."
	echo "--help"
	echo "--list-releases - List of the available Ubuntu releases."
	echo "--list-release-versions release - List the versions for a specific release (e.g '--list-release-versions xenial')."
	echo "--cleanup - Removes the Ubuntu base release from '/tmp'."
	echo "--reuse-cache - Reuse the base ubuntu archive, without downloading it."
	echo "--base-path path - Path of the base ubuntu archive to be used."
	echo ""
	exit 1
}

function log_stdout {
	echo "$1"
}

function log_stderr {
	>&2 echo "E: $1"
}

function list_releases {
	if [[ $RELEASE_LIST == '' ]]
	then
		RELEASE_LIST=`xmllint --html http://cdimage.ubuntu.com/ubuntu-base/releases/ --xpath "/html/body/table" | tail -n +5 | head -n -2 |  sed -r 's/.*<a href="(.*)\/">.*/\1/' | sort -r | sed -r 's/[0-9]+\.[0-9]+(\.[0-9]+)?//g' | sed -r '/^\s*$/d'`
	fi

	log_stdout "$RELEASE_LIST"
}

function list_release_versions {
	release=$1
	release_registry_url=http://cdimage.ubuntu.com/ubuntu-base/releases/${release}/release/
	VERSION_LIST=`xmllint --html ${release_registry_url} --nowarning 2> /dev/null | sed -r 's/.*<a href="(.*\.tar.gz)">(.*)<\/a>.*/\1/' | sed -r 's/^\s*<.*$//' | sed -r '/^\s*$/d' | sed -n '/^ubuntu-base-/p' | sed -r 's/^ubuntu-base-([0-9]+\.[0-9]+(\.[0-9]+)?).*$/\1/' | uniq`
	log_stdout "$VERSION_LIST"
}

function download_ubuntu_base {
	release=$1
	version=$2
	UBUNTU_BASE_TAR_GZ="ubuntu-base-$version-core-amd64.tar.gz"
	wget "cdimage.ubuntu.com/ubuntu-base/releases/$release/release/${UBUNTU_BASE_TAR_GZ}" -P /tmp
	if [ $? == 0 ]
	then
		UBUNTU_BASE_TAR_GZ_PATH=/tmp/${UBUNTU_BASE_TAR_GZ}	
	else
		log_stderr "Failed downloading the Ubuntu base ${RELEASE} (${VERSION}) release."
		exit 1
	fi
}

function create_ext4_image {
	dd if=/dev/zero bs=1${UNIT} count=${SIZE} of=${ROOTFS_IMAGE_PATH}
	if [ $? == 0 ]
	then
		sudo mkfs.ext4 ${ROOTFS_IMAGE_PATH}
		if [ $? != 0 ]
		then
			log_stderr "EXT4 creation failed: exit code $?."
			exit 1
		fi
	else
		log_stderr "EXT4 creation failed: exit code $?."
		exit 1
	fi
}

# Priviledged function.
function validate_build_args {
	if [[ $RELEASE == '' ]] || [[ $SIZE == '' ]] || [[ $UNIT == '' ]] || [[ $VERSION == '' ]]
	then
		echo "E: Incorrect usage. Missing mandatory arguments."
		echo 
		help
		exit 1	
	fi

	if [[ $ROOTFS_IMAGE_PATH == '' ]]
	then
		ROOTFS_IMAGE_PATH=$PWD/ubuntu-${RELEASE}-${VERSION}.rootfs.ext4
	fi
}

function cleanup {
	rm -f ${UBUNTU_BASE_TAR_GZ_PATH}
}

# Priviledged function.
function extract_ubuntu_base_into_ext4_image {
	log_stdout "Mount location (enter for default - /mnt):"
	read MOUNT_DIR
	if [[ $MOUNT_DIR == '' ]]
	then
		MOUNT_DIR=/mnt
	fi

	sudo mount ${ROOTFS_IMAGE_PATH} ${MOUNT_DIR}
	sudo tar -xvf ${UBUNTU_BASE_TAR_GZ_PATH} -C ${MOUNT_DIR}
	sudo umount ${MOUNT_DIR}
}


function parse_args {
	for arg in $@
	do	
		if [[ $wait_for_base_path == 1 ]]
		then
			[[ -f ${arg} ]]	
			if [ $? != 0 ]
			then
				log_stderr "The archive does not exist: `{$arg}`."
			fi

			out=`tar -tf ${arg} 2>&1`
			if [ $? != 0 ]
			then
				log_stderr "Can not query the contents of `${arg}`. The archive may be corrupted."
			fi
			
			if [[ $out == '' ]]
			then
				log_stderr "The archive is empty: `${arg}`."
			fi

			UBUNTU_BASE_TAR_GZ_PATH=$arg
			UBUNTU_BASE_TAR_GZ=`basename -- ${UBUNTU_BASE_TAR_GZ_PATH}`
			wait_for_base_path=0
			continue					
		fi

		if [[ $wait_release == 1 ]]
		then
			RELEASE_LIST=`list_releases`
			echo $RELEASE_LIST | grep $arg &> /dev/null
			if [ $? != 0 ]
			then
				log_stderr "Unkown ubuntu release: '${arg}'."
				exit 1
			fi

			RELEASE=$arg
			wait_release=0

			if [[ $check_version != '' ]]
			then
				VERSION_LIST=`list_release_versions $RELEASE`
				echo $VERSION_LIST | grep $check_version &> /dev/null
				if [ $? != 0 ]
				then
					log_stderr "Unknown ubuntu release version: '${arg}'."
					exit 1
				fi
				VERSION=$check_version
				check_version=''
			fi
			continue
		fi
		
		if [[ $wait_version == 1 ]]
		then
			if [[ $RELEASE != '' ]]
			then
				VERSION_LIST=`list_release_versions $RELEASE`
			else
				check_version=$arg
				wait_version=0
				continue
			fi
			
			echo $VERSION_LIST | grep $arg &> /dev/null
			if [ $? != 0 ]
			then
				log_stderr "Unknown ubuntu release version: '${arg}'."
				exit 1
			fi

			VERSION=$arg
			wait_version=0
			continue
		fi

		if [[ $wait_versions_release == 1 ]]
		then
			RELEASE_LIST=`list_releases`
			echo $RELEASE_LIST | grep $arg &> /dev/null
			if [ $? != 0 ]
			then
				log_stderr "Unkown ubuntu release: '${arg}'."
				exit 1
			fi

			list_release_versions "$arg"
			wait_versions_release=0
			exit 0
		fi

		if [[ $wait_rootfs_image_path == 1 ]]
		then
			ROOTFS_IMAGE_PATH=$arg
			wait_rootfs_image_path=0
			continue
		fi
		
		if [[ $wait_size == 1 ]]
		then
			SIZE=`echo "START${arg}END" | sed -r 's/^START(([2-9][0-9][0-9])|([1-9][0-9][0-9][0-9]+)).*END$/\1/'`
			if [ $SIZE == "START${arg}END" ]
			then
				log_stderr "Rootfs size must be a valid positive number greater than '200'."
				exit 1
			fi
			
			UNIT=`echo "START${arg}END" | sed -r 's/^START.+([M|G])END$/\1/'`
			if [ $UNIT == "START${arg}END" ]
			then
				log_stderr "Rootfs size valid units are: M(egabytes) and G(igabytes)."	
				exit 1
			fi
			wait_size=0
			continue
		fi
		
		if [ $# == 0 ]
		then
			help
			exit 0
		fi

		if [ $arg == "--help" ] && [ $# == 1 ]
		then
			help
			exit 0
		else
			if [ $# != 1 ] && [ $arg == "--help" ]
			then
				help
				exit 1
			fi
		fi

		if [ $arg == "--list-releases" ] && [ $# == 1 ]
		then
			list_releases
			exit 0
		else
			if [ $# != 1 ] && [ $arg == "--list-releases" ]
			then
				help
				exit 1
			fi
		fi
			
		if [ $arg == "--list-release-versions" ] && [[ $# == 2 ]]
		then
			wait_versions_release=1
		else
			if [ $# != 2 ] && [ $arg == "--list-release-versions" ]
			then
				help
				exit 1
			fi
		fi


		if [ $arg == "-r" ] && [[ $RELEASE == '' ]]
		then
			wait_release=1
			continue
		fi
		
		if [ $arg == "-v" ]
		then
			wait_version=1
		fi		

		if [ $arg == "-s" ]
		then
			wait_size=1
			continue
		fi

		if [ $arg == "-o" ]
		then
			wait_rootfs_image_path=1
			continue
		fi

		if [ $arg == "--cleanup" ]
		then
			CLEANUP=1
			continue
		fi

		if [ $arg == "--reuse-cache" ] && [[ $UBUNTU_BASE_TAR_GZ_PATH == '' ]]
		then
			REUSE_CACHE=1
			continue
		fi
		
		if [ $arg == "--base-path" ]
		then
			wait_for_base_path=1
			REUSE_CACHE=0
		fi
	done

	if [[ $check_version != '' ]]
	then
		help
		exit 1
	fi
}

# Priviledged function.
function build_rootfs {
	validate_build_args
	if [[ $REUSE_CACHE == 1 ]]
	then
		UBUNTU_BASE_TAR_GZ_PATH=/tmp/ubuntu-base-${VERSION}-core-amd64.tar.gz
		UBUNTU_BASE_TAR_GZ=`basename -- ${UBUNTU_BASE_TAR_GZ_PATH}`
		[[ -f ${UBUNTU_BASE_TAR_GZ_PATH} ]]
		if [ $? != 0 ]
		then
			log_stdout "Base archive from ${UBUNTU_BASE_TAR_GZ_PATH} does not exist."
			download_ubuntu_base ${RELEASE} ${VERSION}
		fi
	else
		download_ubuntu_base ${RELEASE} ${VERSION}
	fi
	create_ext4_image
	extract_ubuntu_base_into_ext4_image
	
	if [[ $CLEANUP == 1 ]]
	then
		cleanup
	fi
}
	
function main {
	parse_args $@
	build_rootfs
}

main $@
