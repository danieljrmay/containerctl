#!/usr/bin/env bash
# containerctl-create-container-drupal9-addon-dev-fedora
#
# Author: Daniel J. R. May
#
# This script creates a container based on the
# drupal9-addon-dev-fedora image.
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
drupal9_dir="${lib_dir}/drupal/9"

# Script constants
declare -r image='drupal9-addon-dev-fedora'

# Source containerctl.library.bash
# shellcheck source=../../local/share/containerctl/containerctl.lib.bash
if source "$lib_path"; then
	info 'Started containerctl-create-image-drupal9-addon-dev-fedora script'
	debug 'Sourced containerctl.lib.bash'
	debug "script_dir=${script_dir}"
	debug "root_dir=${root_dir}"
	debug "lib_path=${lib_path}"
	debug "bin_dir=${bin_dir}"
else
	echo 'ERROR: unable to source containerctl.lib.bash'
	exit 1
fi

# Load drupal9 environment variables
# shellcheck source=../../local/share/containerctl/drupal/9/environment.inc.bash
if source "$lib_dir/drupal/9/environment.inc.bash"; then
	debug "Sourced $lib_dir/drupal/9/environment.inc.bash"
else
	error "ERROR: unable to source $lib_dir/drupal/9/environment.inc.bash"
	exit $_exit_status_file_not_found
fi

# Output the environment variables values being used
info "Using the following environment variables:"
info "DRUPAL9_VERSION=$DRUPAL9_VERSION"
info "HOST_CUSTOM_MODULES_DIR=$HOST_CUSTOM_MODULES_DIR"
info "HOST_CUSTOM_THEMES_DIR=$HOST_CUSTOM_THEMES_DIR"

check_image_exists "$image"

verbose "Removing drupal9-dev secret"
podman secret rm drupal9-dev >/dev/null 2>&1

verbose "Creating drupal9-dev secret"
podman secret create drupal9-dev "$drupal9_dir/drupal9-dev.secrets"

verbose "Create the container"
podman run \
	--name "$image" \
	--secret source=drupal9-dev,type=mount,mode=400,target=configure-drupal9-dev \
	--volume "$HOST_CUSTOM_MODULES_DIR":/var/www/html/sites/all/modules/custom:ro,z \
	--volume "$HOST_CUSTOM_THEMES_DIR":/var/www/html/sites/all/themes/custom:ro,z \
	--publish "8090:80" \
	--detach \
	$image

verbose "Done"

msg "You should be able to access your new drupal 9 container at http://localhost:8090/install.php"
exit $_exit_status_ok
