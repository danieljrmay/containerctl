#!/usr/bin/env bash
# containerctl-create-container-drupal7-addon-dev-fedora
#
# Author: Daniel J. R. May
#
# This script creates a container based on the
# drupal7-addon-dev-fedora image.
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
drupal7_dir="${lib_dir}/drupal/7"

# Script constants
declare -r image='drupal7-addon-dev-fedora'

# Source containerctl.library.bash
# shellcheck source=../../local/share/containerctl/containerctl.lib.bash
if source "$lib_path"; then
	info 'Started containerctl-create-image-drupal7-addon-dev-fedora script'
	debug 'Sourced containerctl.lib.bash'
	debug "script_dir=${script_dir}"
	debug "root_dir=${root_dir}"
	debug "lib_path=${lib_path}"
	debug "bin_dir=${bin_dir}"
else
	echo 'ERROR: unable to source containerctl.lib.bash'
	exit 1
fi

# Load drupal7 environment variables
# shellcheck source=../../local/share/containerctl/drupal/7/environment.inc.bash
if source "$lib_dir/drupal/7/environment.inc.bash"; then
	debug "Sourced $lib_dir/drupal/7/environment.inc.bash"
else
	error "ERROR: unable to source $lib_dir/drupal/7/environment.inc.bash"
	exit $_exit_status_file_not_found
fi

# Output the environment variables values being used
info "Using the following environment variables:"
info "DRUPAL7_VERSION=$DRUPAL7_VERSION"
info "HOST_CUSTOM_MODULES_DIR=$HOST_CUSTOM_MODULES_DIR"
info "HOST_CUSTOM_THEMES_DIR=$HOST_CUSTOM_THEMES_DIR"

check_image_exists "$image"

verbose "Removing drupal7-dev secret"
podman secret rm drupal7-dev >/dev/null 2>&1

verbose "Creating drupal7-dev secret"
podman secret create drupal7-dev "$drupal7_dir/drupal7-dev.secrets"

verbose "Create the container"
podman run \
	--name "$image" \
	--secret source=drupal7-dev,type=mount,mode=400,target=configure-drupal7-dev \
	--volume "$HOST_CUSTOM_MODULES_DIR":/var/www/html/sites/all/modules/custom:ro,z \
	--volume "$HOST_CUSTOM_THEMES_DIR":/var/www/html/sites/all/themes/custom:ro,z \
	--publish "8090:80" \
	--detach \
	$image

verbose "Done"

msg "You should be able to access your new drupal 7 container at http://localhost:8090/install.php"
exit $_exit_status_ok
