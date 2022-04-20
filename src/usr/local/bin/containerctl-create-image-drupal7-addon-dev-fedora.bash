#!/usr/bin/env bash
# containerctl-create-image-drupal7-addon-dev-fedora
#
# Author: Daniel J. R. May
# Version: 0.1, 20 April 2022
#
# This script creates a container image of drupal 7, httpd, mariadb
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

# Load drupal 7 environment variables
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
drupal7_tarball="${drupal7_dir}/drupal-${DRUPAL7_VERSION}.tar.gz"
drupal7_extracted_dir="${drupal7_dir}/drupal-${DRUPAL7_VERSION}"

check_image_does_not_exist "$image"

# Check if we need to download the drupal7 release tarball
if [ -r "${drupal7_tarball}" ]; then
	verbose "Using previous download of drupal 7 release: ${drupal7_tarball}"
else
	verbose "Downloading drupal 7 release $DRUPAL7_VERSION"
	(
		curl \
			--location \
			--output "${drupal7_tarball}" \
			"https://ftp.drupal.org/files/projects/drupal-${DRUPAL7_VERSION}.tar.gz"
	) || (
		error "Failed to download drupal 7 release $DRUPAL7_VERSION" &&
			exit $_exit_status_download_failure
	)
fi

# TODO download and check the CHECKSUMS
# See https://www.drupal.org/project/drupal/releases/7.89

# Check if we need to extract the drupal 7 tarball
if [ -d "${drupal7_extracted_dir}" ]; then
	verbose "Using previously extracted drupal 7 release: ${drupal7_extracted_dir}"
else
	verbose "Extracting ${drupal7_tarball}"
	(
		tar --extract --ungzip --file "${drupal7_tarball}" --directory "${drupal7_dir}"
	) || (
		error "Unable to extract ${drupal7_tarball}" &&
			exit $_exit_status_operation_failure
	)
fi

verbose "Pull the latest version of Fedora"
buildah pull registry.fedoraproject.org/fedora:latest

verbose "Create a new image based on the latest version fedora"
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

verbose "Copy the drupal 7 files"
buildah copy "$image" "${drupal7_extracted_dir}" /var/www/html
buildah copy "$image" "${drupal7_dir}/apache/drupal7.conf" /etc/httpd/conf.d/drupal7-add-on-devel.conf
buildah copy "$image" "${drupal7_dir}/systemd/configure-drupal7-dev.bash" /usr/local/bin/configure-drupal7-dev
buildah copy "$image" "${drupal7_dir}/systemd/configure-drupal7-dev.service" /etc/systemd/system/configure-drupal7-dev.service

verbose "Create settings.php from default.settings.php"
buildah run "$image" -- cp /var/www/html/sites/default/default.settings.php /var/www/html/sites/default/settings.php

verbose "Create the files folder"
buildah run "$image" -- mkdir /var/www/html/sites/default/files

verbose "Configure files permissions"
buildah run "$image" -- chown apache:apache /var/www/html/sites/default/files
buildah run "$image" -- chown apache:apache /var/www/html/sites/default/settings.php
buildah run "$image" -- chmod a+x /usr/local/bin/configure-drupal7-dev

verbose "Enable services"
buildah run "$image" -- systemctl enable httpd.service
buildah run "$image" -- systemctl enable mariadb.service
buildah run "$image" -- systemctl enable php-fpm.service
buildah run "$image" -- systemctl enable configure-drupal7-dev.service

verbose "Configure the environment variables"
buildah config --env DRUPAL7_DATABASE_NAME="DRUPAL7_DATABASE_NAME" "$image"
buildah config --env DRUPAL7_DATABASE_USER="DRUPAL7_DATABASE_USER" "$image"
buildah config --env DRUPAL7_DATABASE_PASSWORD="DRUPAL7_DATABASE_PASSWORD" "$image"

verbose "Expose port 80"
buildah config --port 80 "$image"

verbose "Configure systemd init command as the command to get everthing going"
buildah config --cmd "/usr/sbin/init" "$image"

verbose "Commit the image"
buildah commit "$image" "$image"

verbose "Delete the container"
buildah rm "$image"

verbose "Done"
exit $_exit_status_ok
