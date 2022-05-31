#!/usr/bin/env bash
#
# configure-drupal9-dev
#
# Author: Daniel J. R. May
#
# This script configures the drupal 9 installation for development by
# modifying the settings.php file. This script should be called only
# once by the configure-drupal9-dev service. It creates a lock file
# to prevent repeated executions.
#
# For more information (or to report issues) go to
# https://github.com/danieljrmay/containerctl

declare -r identifier='configure-drupal9-dev'
declare -r lock_path='/var/lock/configure-drupal9-dev.lock'
declare -r secrets_path='/run/secrets/configure-drupal9-dev'
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
# shellcheck source=../drupal9-dev.secrets
if source $secrets_path; then
	systemd-cat --identifier=$identifier \
		echo "Successfully sourced $secrets_path secrets file."
else
	systemd-cat \
		--identifier=$identifier \
		--priority=warning \
		echo "Failed to source secrets file $secrets_path so using default values."
	DRUPAL9_DATABASE_NAME=drupal
	DRUPAL9_DATABASE_USER=drupal_db_user
	DRUPAL9_DATABASE_PASSWORD=drupal_db_pwd
fi

# Database configuration
sql=$(
	cat <<EOF
CREATE DATABASE ${DRUPAL9_DATABASE_NAME};
GRANT ALL ON ${DRUPAL9_DATABASE_NAME}.* TO '${DRUPAL9_DATABASE_USER}'@'localhost' IDENTIFIED BY '${DRUPAL9_DATABASE_PASSWORD}';
FLUSH   PRIVILEGES;
EOF
)

if mysql --user=root --execute "$sql"; then
	systemd-cat \
		--identifier=$identifier \
		echo "Created and configured database $DRUPAL9_DATABASE_NAME for $DRUPAL9_DATABASE_USER@localhost."
else
	systemd-cat \
		--identifier=$identifier \
		--priority=error \
		echo "Failed to create the database $DRUPAL9_DATABASE_NAME so exiting."
	exit 3
fi

# Settings file configuration
settings_appendages=$(
	cat <<EOF

/**
 * BEGIN: configure-drupal9-dev appendages
 */ 
\$databases['default']['default'] = array (
  'database' => '${DRUPAL9_DATABASE_NAME}',
  'username' => '${DRUPAL9_DATABASE_USER}',
  'password' => '${DRUPAL9_DATABASE_PASSWORD}',
  'host' => 'localhost',
  'prefix' => '',
  'port' => '3306',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
  'driver' => 'mysql',
);

\$settings['trusted_host_patterns'] = [
  '^localhost:8090$',
  '^localhost$',
];

/**
 * END: configure-drupal9-dev appendages
 */

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
