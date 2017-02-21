#!/bin/bash

# @file tools/travis/run-tests.sh
#
# Copyright (c) 2014-2017 Simon Fraser University Library
# Copyright (c) 2010-2017 John Willinsky
# Distributed under the GNU GPL v2. For full terms see the file docs/COPYING.
#
# Script to run data build, unit, and integration tests.
#

set -xe

export DUMMY_PDF=~/dummy.pdf
export DUMMY_ZIP=~/dummy.zip
export BASEURL="http://localhost"
export DBHOST=localhost
export DBNAME=ojs
export DBUSERNAME=ojs
export DBPASSWORD=ojs
export FILESDIR=files
export DATABASEDUMP=~/database.sql.gz

# Install required software
sudo apt-get install a2ps libbiblio-citation-parser-perl libhtml-parser-perl

# Generate sample files to use for testing.
echo "This is a PKP Plugin test" | a2ps -o - | ps2pdf - ${DUMMY_PDF} # PDF format
zip ${DUMMY_ZIP} ${DUMMY_PDF} # Zip format; add PDF dummy as contents

# Create the database.
if [[ "$TEST" == "pgsql" ]]; then
	psql -c "CREATE DATABASE \"ojs\";" -U postgres
	psql -c "CREATE USER \"ojs\" WITH PASSWORD 'ojs';" -U postgres
	psql -c "GRANT ALL PRIVILEGES ON DATABASE \"ojs\" TO \"ojs\";" -U postgres
	echo "localhost:5432:ojs:ojs:ojs" > ~/.pgpass
	chmod 600 ~/.pgpass
	export DBTYPE=PostgreSQL
elif [[ "$TEST" == "mysql" ]]; then
	mysql -u root -e 'CREATE DATABASE `ojs` DEFAULT CHARACTER SET utf8'
	mysql -u root -e "GRANT ALL ON \`ojs\`.* TO \`ojs\`@localhost IDENTIFIED BY 'ojs'"
	export DBTYPE=MySQL
fi

# Prep files
cp config.TEMPLATE.inc.php config.inc.php
sed -i -e "s/enable_cdn = On/enable_cdn = Off/" config.inc.php # Disable CDN use

mkdir ${FILESDIR}

# Run data build suite
if [[ "$TEST" == "mysql" ]]; then
    ./plugins/$PKP_PLUGIN_CATEGORY/$PKP_PLUGIN_NAME/tools/travis/runAllTests.sh -bH
else
	./plugins/$PKP_PLUGIN_CATEGORY/$PKP_PLUGIN_NAME/tools/travis/runAllTests.sh -b
fi

# Dump the completed database.
if [[ "$TEST" == "pgsql" ]]; then
	pg_dump --clean --username=$DBUSERNAME --host=$DBHOST $DBNAME | gzip -9 > $DATABASEDUMP
elif [[ "$TEST" == "mysql" ]]; then
	mysqldump --user=$DBUSERNAME --password=$DBPASSWORD --host=$DBHOST $DBNAME | gzip -9 > $DATABASEDUMP
fi

# Run test suite.
sudo rm -f cache/*.php
if [[ "$TEST" == "mysql" ]]; then
    if [[ "$TEST_CURRENT_PKP_PLUGIN" == "1" ]]; then
        echo "====================WE ARE USING THE PLUGINS RUN_TEST===================="
        ./plugins/$PKP_PLUGIN_CATEGORY/$PKP_PLUGIN_NAME/tools/travis/runAllTests.sh -m
    else
        ./plugins/$PKP_PLUGIN_CATEGORY/$PKP_PLUGIN_NAME/tools/travis/runAllTests.sh -CcPpfH
    fi
else
	if [[ "$TEST_CURRENT_PKP_PLUGIN" == "1" ]]; then
        echo "====================WE ARE USING THE PLUGINS RUN_TEST===================="
        ./plugins/$PKP_PLUGIN_CATEGORY/$PKP_PLUGIN_NAME/tools/travis/runAllTests.sh -m
    else
        ./plugins/$PKP_PLUGIN_CATEGORY/$PKP_PLUGIN_NAME/tools/travis/runAllTests.sh -CcPpf
    fi
fi