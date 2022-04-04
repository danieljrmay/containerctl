#!/usr/bin/env bash
#
# containerctl
#
# Author: Daniel J. R. May
#
# A script to help manage containers.
#
# For more information (or to report issues) go to
# https://github.com/danieljrmay/containerctl

# Define paths and find out if we are executing this script in a
# development or installed context
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
root_dir=$(realpath "${script_dir}/../../..")
lib_path=$(realpath "${root_dir}/usr/local/share/containerctl/containerctl.lib.bash")
bin_dir=$(realpath "${root_dir}/usr/local/bin")
image_recipe_prefix="${bin_dir}/containerctl-create-image-"

# Source containerctl.library.bash
# shellcheck source=../../local/share/containerctl/containerctl.lib.bash
if source "$lib_path"; then
	debug 'Started containerctl script'
	debug 'Sourced containerctl.lib.bash'
	debug "script_dir=${script_dir}"
	debug "root_dir=${root_dir}"
	debug "lib_path=${lib_path}"
	debug "bin_dir=${bin_dir}"
else
	echo 'ERROR: unable to source containerctl.lib.bash'
	exit 1
fi

exec_create_image() {
	debug "In exec_create_image() with arguments $*"

	if [ $# -ne 1 ]; then
		error "The create-image command only accepts one argument, an image recipe name. Possible image recipes:"
		exec_list_image_recipes
		exit $_exit_status_syntax_error
	fi

	if [ -x "${image_recipe_prefix}$1" ]; then
		verbose "Found image creation script ${image_recipe_prefix}$1"
		exec "${image_recipe_prefix}$1"
	elif [ -r "${image_recipe_prefix}$1.bash" ]; then
		verbose "Found image creation script ${image_recipe_prefix}$1.bash"
		exec bash "${image_recipe_prefix}$1.bash"
	else
		error "Can not find readable image creation script corresponding to recipe '$1'"
	fi
}

exec_init_host() {
	debug "In exec_init_host() with arguments $*"

	if [ $# -ne 0 ]; then
		warn "The init-host command does not accept any arguments, so '$*' is being ignored"
	fi

	# Check if SELinux is available (enabled or disabled) on this host
	if [ -x /usr/sbin/selinuxenabled ]; then
		verbose 'Host system is SELinux compatible'
	else
		info 'Host system is not SELinux compatible, so there is nothing to do.'
		exit $_exit_status_ok
	fi

	# Check if SELinux is enabled
	if selinuxenabled; then
		verbose 'SELinux is enabled'
	else
		warn 'SELinux is disabled on the host system, so there is nothing to do.'
		exit $_exit_status_ok
	fi

	# Turn on SELinux boolean 'container_manage_cgroup' if required
	if [ "$(getsebool container_manage_cgroup)" = 'container_manage_cgroup --> on' ]; then
		verbose "SELinux boolean 'container_manage_cgroup' is already on"
		exit $_exit_status_ok
	else
		message="The SELinux boolean 'container_manage_cgroup' is currently off, and "
		message+='needs to be turned on by executing the command:\n\n'
		message+='\tsudo setsebool -P container_manage_cgroup true\n\n'
		message+='This script will attempt to execute this command now, so you may be asked '
		message+='for your administrator password.\nIf you understandably do not want to enter '
		message+='your adminstrator password into this script, simply press Ctrl+C\nto stop '
		message+='this script and enter the above command manually.'
		msg "$message"
		sudo setsebool -P container_manage_cgroup true
	fi
}

exec_list_image_recipes() {
	debug "In exec_list_image_recipes() with arguments $*"

	if [ $# -ne 0 ]; then
		warn "The list-image-recipes command does not accept any arguments, so '$*' is being ignored"
	fi

	for f in "${image_recipe_prefix}"*; do
		if [[ $(basename --suffix=.bash "$f") =~ containerctl-create-image-(.+) ]]; then
			echo "${BASH_REMATCH[1]}"
		fi
	done
}

# Execute the '--help' option flag by printing help & usage information
exec_help() {
	echo 'containerctl [OPTIONS] <COMMAND> [ARGS]'
	echo
	echo 'Options:'
	echo -e "\t-d, --debug\tPrint loads of messages (useful for debugging)"
	echo -e "\t-h, --help\tPrint this help message"
	echo -e "\t-v, --verbose\tPrint messages when running"
	echo -e "\t-V, --version\tPrint version information"
	echo
	echo 'Commands:'
	echo -e "\tcreate-image\t\tCreate a container image"
	echo -e "\tinit-host\t\tInitialize the container host machine"
	echo -e "\tlist-image-recipes\tList the available image recipes"
	echo
	echo 'Get command specific help with:'
	echo -e "\containerctl <COMMAND> -h"
	echo
	echo 'For more information see <https://github.com/danieljrmay/containerctl>'
}

# Execute the '--version' optoin flag by printing version information
exec_version() {
	echo "containerctl version $_version"
}

# Process the command line arguments
while true; do
	case "$1" in
	'create-image')
		shift
		debug "create-image command detected with arguments: $*"
		exec_create_image "$@"
		exit $?
		;;
	'init-host')
		shift
		debug "init-host command detected with arguments: $*"
		exec_init_host "$@"
		exit $?
		;;
	'list-image-recipes')
		shift
		debug "list-image-recipes command detected with arguments: $*"
		exec_list_image_recipes "$@"
		exit $?
		;;
	'-d' | '--debug')
		shift
		debug '-d | --debug option detected'
		_verbosity=$_verbosity_debug
		continue
		;;
	'-h' | '--help')
		shift
		debug '-h | --help option detected'
		exec_help
		exit $?
		;;
	'-v' | '--verbose')
		shift
		debug '-v | --verbose option detected'
		_verbosity=$_verbosity_verbose
		continue
		;;
	'-V' | '--version')
		shift
		debug '-V | --version option detected'
		exec_version
		exit $?
		;;
	'--')
		shift
		debug '-- option detected'
		continue
		;;
	'')
		error "Illegal invokation, please check your syntax:"
		exec_help
		exit $?
		;;
	*)
		error "'$1' is not a recognised option or command, please check your syntax:"
		exec_help
		exit $?
		;;
	esac
done
