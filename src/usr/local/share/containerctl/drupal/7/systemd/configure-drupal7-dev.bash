#!/usr/bin/env bash
#
# configure-drupal7-dev
#
# Author: Daniel J. R. May
#
# This script configures the drupal 7 installation for development by
# modifying the settings.php file. This script should be called only
# once by the configure-drupal7-dev service. It creates a lock file
# to prevent repeated executions.
#
# For more information (or to report issues) go to
# https://github.com/danieljrmay/containerctl

declare -r identifier='configure-drupal7-dev'
declare -r lock_path='/var/lock/configure-drupal7-dev.lock'
declare -r secrets_path='/run/secrets/configure-drupal7-dev'
declare -r settings_path='/var/www/html/sites/default/settings.php'

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
# shellcheck source=../drupal7-dev.secrets
if source $secrets_path; then
	systemd-cat --identifier=$identifier \
		echo "Successfully sourced $secrets_path secrets file."
else
	systemd-cat \
		--identifier=$identifier \
		--priority=warning \
		echo "Failed to source secrets file $secrets_path so using default values."
	DRUPAL7_DATABASE_NAME=drupal
	DRUPAL7_DATABASE_USER=drupal_db_user
	DRUPAL7_DATABASE_PASSWORD=drupal_db_pwd
fi

# Database configuration
sql=$(
	cat <<EOF
CREATE DATABASE ${DRUPAL7_DATABASE_NAME};
GRANT ALL ON ${DRUPAL7_DATABASE_NAME}.* TO '${DRUPAL7_DATABASE_USER}'@'localhost' IDENTIFIED BY '${DRUPAL7_DATABASE_PASSWORD}';
FLUSH   PRIVILEGES;
EOF
)

if mysql --user=root --execute "$sql"; then
	systemd-cat \
		--identifier=$identifier \
		echo "Created and configured database $DRUPAL7_DATABASE_NAME for $DRUPAL7_DATABASE_USER@localhost."
else
	systemd-cat \
		--identifier=$identifier \
		--priority=error \
		echo "Failed to create the database $DRUPAL7_DATABASE_NAME so exiting."
	exit 3
fi

# Settings file configuration
settings_appendages=$(
	cat <<EOF

/**
 * configure-drupal7-dev appendages
 */ 
\$databases = array (
  'default' => 
  array (
    'default' => 
    array (
      'driver' => 'mysql',
      'database' => '${DRUPAL7_DATABASE_NAME}',
      'username' => '${DRUPAL7_DATABASE_USER}',
      'password' => '${DRUPAL7_DATABASE_PASSWORD}',
      'host' => 'localhost', 
      'charset' => 'utf8mb4',
      'collation' => 'utf8mb4_general_ci',
    ),
  ),
);

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
