#!/usr/bin/env bash
# containerctl-create-container-backdrop-addon-dev-debian
#
# Author: Daniel J. R. May
#
# This script creates a container based on the
# backdrop-addon-dev-debian image.
#
# For more information (or to report issues) go to
# https://github.com/danieljrmay/containerctl
#
# Define paths and find out if we are executing this script in a
# development or installed context
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
root_dir=$(realpath "${script_dir}/../../..")
lib_dir="${root_dir}/usr/local/share/containerctl"
lib_path="${lib_dir}/containerctl.lib.bash"
bin_dir="${root_dir}/usr/local/bin"
backdrop_dir="${lib_dir}/backdrop"

# Script constants
declare -r image='backdrop-addon-dev-debian'

# Source containerctl.library.bash
# shellcheck source=../../local/share/containerctl/containerctl.lib.bash
if source "$lib_path"; then
	info 'Started containerctl-create-image-backdrop-addon-dev-debian script'
	debug 'Sourced containerctl.lib.bash'
	debug "script_dir=${script_dir}"
	debug "root_dir=${root_dir}"
	debug "lib_path=${lib_path}"
	debug "bin_dir=${bin_dir}"
else
	echo 'ERROR: unable to source containerctl.lib.bash'
	exit 1
fi

# Load backdrop environment variables
# shellcheck source=../../local/share/containerctl/backdrop/environment.inc.bash
if source "$lib_dir/backdrop/environment.inc.bash"; then
	debug "Sourced $lib_dir/backdrop/environment.inc.bash"
else
	error "ERROR: unable to source $lib_dir/backdrop/environment.inc.bash"
	exit $_exit_status_file_not_found
fi

# Output the environment variables values being used
info "Using the following environment variables:"
info "BACKDROP_VERSION=$BACKDROP_VERSION"
info "HOST_CUSTOM_MODULES_DIR=$HOST_CUSTOM_MODULES_DIR"
info "HOST_CUSTOM_THEMES_DIR=$HOST_CUSTOM_THEMES_DIR"

check_image_exists "$image"

# TODO create the secret if if does not already exist

verbose "Create the container"
podman run \
	--name "$image" \
	--secret source=backdrop-dev,type=mount,mode=400,target=configure-backdrop-dev \
	--volume "$HOST_CUSTOM_MODULES_DIR":/var/www/html/modules/custom:ro,z \
	--volume "$HOST_CUSTOM_THEMES_DIR":/var/www/html/themes/custom:ro,z \
	--publish "8080:80" \
	--detach \
	$image

verbose "Done"
exit $_exit_status_ok
