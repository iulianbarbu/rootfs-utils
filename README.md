This repo stands for utility tools which might help when buidling specific rootfs images.
At the moment, this repo contains a bash script which can create rootfs ext4 images based on ubuntu base releases.

# Usage `create-ubuntu-rootfs.sh`

### Usage: ./create-ubuntu-rootfs [params]

### Mandatory:  
__-r__ _release_ - _Specify the release name (e.g '-r xenial')_.  
__-v__ - _The release version which will be downloaded (e.g '-v 16.04' - coresponds to 'xenial' release)_.  
__-s__ _(digit+)(M(egabytes)|G(igabytes))_ - _Specify the size of the ext4 rootfs image. Minimal size is 200M_.  

### Optional:  
__-o__ _path_ - _Rootfs image path_.  
__--help__  
__--list-releases__ - _List of the available Ubuntu releases_.  
__--list-release-versions__ _release_ - _List the versions for a specific release (e.g '--list-release-versions xenial')_.  
__--cleanup__ - _Removes the Ubuntu base release from '/tmp'_.  
__--reuse-cache__ - _Reuse the base ubuntu archive, without downloading it_.  
__--base-path path__ - _Path of the base ubuntu archive to be used_.  

# Support

This script can create ubuntu based rootfs ext4 images for x86_64 systems.
In the near future, support for building ubuntu based rootfs ext4 images for arm will be added.
