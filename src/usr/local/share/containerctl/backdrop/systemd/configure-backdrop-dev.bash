#!/usr/bin/env bash
#
# configure-backdrop-dev
#
# Author: Daniel J. R. May
#
# This script configures the backdrop installation for development by
# modifying the settings.php file. This script should be called only
# once by the configure-backdrop-dev service. It creates a lock file
# to prevent repeated executions.
#
# For more information (or to report issues) go to
# https://github.com/danieljrmay/containerctl

declare -r identifier='configure-backdrop-dev'
declare -r lock_path='/var/lock/configure-backdrop-dev.lock'
declare -r secrets_path='/run/secrets/configure-backdrop-dev'
declare -r settings_path='/var/www/html/settings.php'

systemd-cat --identifier=$identifier echo 'Starting script.'

# Check that this script has not already run, by checking for a lock
# file.
if [ -f "$lock_path" ]; then
	systemd-cat --identifier=$identifier --priority=warning \
		echo "Lock file $lock_path already exists, exiting."
	exit 1
else
	(
		touch $lock_path &&
			systemd-cat \
				--identifier=$identifier \
				echo "Created $lock_path to prevent the re-running of this script."
	) || (
		systemd-cat \
			--identifier=$identifier \
			--priority=error \
			echo "Failed to create $lock_path so exiting." &&
			exit 1
	)
fi

# Source the secrets file if it exists, if it doesn't then use some
# defaults and report a warning.
# shellcheck source=../backdrop.secrets
if source $secrets_path; then
	systemd-cat --identifier=$identifier \
		echo "Successfully sourced $secrets_path secrets file."
else
	systemd-cat \
		--identifier=$identifier \
		--priority=warning \
		echo "Failed to source secrets file $secrets_path so using default values."
	BACKDROP_DATABASE_NAME=backdrop
	BACKDROP_DATABASE_USER=backdrop_db_user
	BACKDROP_DATABASE_PASSWORD=backdrop_db_pwd
fi

# Database configuration
sql=$(
	cat <<EOF
CREATE DATABASE ${BACKDROP_DATABASE_NAME};
GRANT ALL ON ${BACKDROP_DATABASE_NAME}.* TO '${BACKDROP_DATABASE_USER}'@'localhost' IDENTIFIED BY '${BACKDROP_DATABASE_PASSWORD}';
FLUSH   PRIVILEGES;
EOF
)

if mysql --user=root --execute "$sql"; then
	systemd-cat \
		--identifier=$identifier \
		echo "Created and configured database $BACKDROP_DATABASE_NAME for $BACKDROP_DATABASE_USER@localhost."
else
	systemd-cat \
		--identifier=$identifier \
		--priority=error \
		echo "Failed to create the database $BACKDROP_DATABASE_NAME so exiting."
	exit 3
fi

# Backdrop settings.php configuration
match_text='mysql://user:pass@localhost/database_name'
replacement_text="mysql://$BACKDROP_DATABASE_USER:$BACKDROP_DATABASE_PASSWORD@localhost/$BACKDROP_DATABASE_NAME"

if sed -i "s#${match_text}#${replacement_text}#g" $settings_path; then
	systemd-cat \
		--identifier=$identifier \
		echo "Updated the database connection configuration in the settings.php file."
else
	systemd-cat \
		--identifier=$identifier \
		--priority=error \
		echo "Failed to update the database connection configuration in the the settings.php file."
	exit 2
fi

# Settings file configuration
settings_appendages=$(
	cat <<'EOF'

/**
 * configure-backdrop-dev appendages
 */ 
$settings['trusted_host_patterns'] = array(
    '^localhost:8080$', 
    '^localhost$',
);
$database_charset = 'utf8mb4';
EOF
)

if (echo "$settings_appendages" >>$settings_path); then
	systemd-cat \
		--identifier=$identifier \
		echo "Updated the settings.php file."
else
	systemd-cat \
		--identifier=$identifier \
		--priority=error \
		echo "Failed to update the settings.php file."
	exit 3
fi

systemd-cat --identifier=$identifier echo 'Ending script.'
