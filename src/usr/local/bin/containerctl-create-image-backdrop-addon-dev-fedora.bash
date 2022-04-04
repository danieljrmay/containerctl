#!/usr/bin/env bash
# containerctl-create-image-backdrop-addon-dev-fedora
#
# Author: Daniel J. R. May
#
# This script creates a container image of backdrop, httpd, mariadb
# and various php libraries on a fedora base.
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
declare -r image='backdrop-addon-dev-fedora'

# Source containerctl.library.bash
# shellcheck source=../../local/share/containerctl/containerctl.lib.bash
if source "$lib_path"; then
	info 'Started containerctl-create-image-backdrop-addon-dev-fedora script'
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
backdrop_zip="${backdrop_dir}/backdrop-${BACKDROP_VERSION}.zip"
backdrop_unzip_dir="${backdrop_dir}/backdrop-${BACKDROP_VERSION}"

check_image_does_not_exist "$image"

# Check if we need to download the backdrop release zip
if [ -r "${backdrop_zip}" ]; then
	verbose "Using previous download of backdrop release: ${backdrop_zip}"
else
	verbose "Downloading backdrop release $BACKDROP_VERSION"
	(
		curl \
			--location \
			--output "${backdrop_zip}" \
			"https://github.com/backdrop/backdrop/releases/download/$BACKDROP_VERSION/backdrop.zip"
	) || (
		error "Failed to download backdrop release $BACKDROP_VERSION" &&
			exit $_exit_status_download_failure
	)
fi

# Check if we need to unzip the backdrop release
if [ -d "${backdrop_unzip_dir}" ]; then
	verbose "Using previously unzipped backdrop release: ${backdrop_unzip_dir}"
else
	verbose "Unzipping ${backdrop_zip}"
	(
		unzip -d "${backdrop_unzip_dir}" "${backdrop_zip}"
	) || (
		error "Unable to unzip ${backdrop_zip}" &&
			exit $_exit_status_operation_failure
	)
fi

verbose "Pull the latest version of Fedora"
buildah pull registry.fedoraproject.org/fedora:latest

verbose "Create a new image based on the latest version CentOS Stream 8"
buildah from --name "$image" registry.fedoraproject.org/fedora:latest

verbose "Install RPMs and clean up"
buildah run "$image" -- dnf --assumeyes update
buildah run "$image" -- dnf --assumeyes install \
	mariadb-server \
	php \
	php-fpm \
	php-gd \
	php-json \
	php-mbstring \
	php-mysqlnd \
	php-pecl-zip \
	php-xml
buildah run "$image" -- dnf --assumeyes clean all

verbose "Copy the backdrop files"
buildah copy "$image" "${backdrop_unzip_dir}/backdrop" /var/www/html
buildah copy "$image" "${backdrop_dir}/apache/backdrop.conf" /etc/httpd/conf.d/backdrop-add-on-devel.conf
buildah copy "$image" "${backdrop_dir}/systemd/configure-backdrop-dev.bash" /usr/local/bin/configure-backdrop-dev
buildah copy "$image" "${backdrop_dir}/systemd/configure-backdrop-dev.service" /etc/systemd/system/configure-backdrop-dev.service

verbose "Configure files permissions"
buildah run "$image" -- chown apache:apache /var/www/html/files
buildah run "$image" -- chown apache:apache /var/www/html/settings.php
buildah run "$image" -- chmod a+x /usr/local/bin/configure-backdrop-dev

verbose "Enable services"
buildah run "$image" -- systemctl enable httpd.service
buildah run "$image" -- systemctl enable mariadb.service
buildah run "$image" -- systemctl enable php-fpm.service
buildah run "$image" -- systemctl enable configure-backdrop-dev.service

verbose "Configure the environment variables"
buildah config --env BACKDROP_DATABASE_NAME="BACKDROP_DATABASE_NAME" "$image"
buildah config --env BACKDROP_DATABASE_USER="BACKDROP_DATABASE_USER" "$image"
buildah config --env BACKDROP_DATABASE_PASSWORD="BACKDROP_DATABASE_PASSWORD" "$image"

verbose "Expose port 80"
buildah config --port 80 "$image"

verbose "Configure systemd init command as the command to get everthing going"
buildah config --cmd "/usr/sbin/init" "$image"

verbose "Commit the image"
buildah commit "$image" "$image"

verbose "Done"
exit $_exit_status_ok
