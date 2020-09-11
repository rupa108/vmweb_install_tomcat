#!/bin/bash
set -e -o pipefail

#########################################################################
# Change to taste
CATALINA_BASE="${CATALINA_BASE:-/var/lib/tomcat9}"
APP_DIR="${CATALINA_BASE}/webapps/vmweb"
FILES4SAVE=(
	"${APP_DIR}/WEB-INF/web.xml"
	"${APP_DIR}/WEB-INF/classes/dbconfig.properties"
	"${APP_DIR}/WEB-INF/classes/AuthenticationManager_jaas.config" 
	"${APP_DIR}/WEB-INF/lib/mariadb-java-client-2.3.0.jar"
)
#########################################################################
# Check call and output help if needed
if [ $# -ne 1 ] || [[ $1 == -* ]]; then
	cat <<_
$(basename $0), Install the given WAR file in ${APP_DIR}

  Usage:
  $(basename $0) [input WAR file]

  The utility will also stop/start tomacat and take care of saving the
  contetnt of the following files and put the back in place after install:

_
	printf "  %s\n"  "${FILES4SAVE[@]}"
	echo
	exit 3
fi
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root" 
	exit 1
fi
#########################################################################
# Main program
if [[ $1 == /* ]]; then
	FULL_NAME="${1}"
else
	T_NAME="${PWD}/${1}"
	FULL_NAME="$(cd $(dirname ${T_NAME}); pwd)/$(basename ${T_NAME})"
fi

########################################################################
# Handle files that should be saved and put back after install
FNOTFOUND=()
FFOUND=()
for f_name in "${FILES4SAVE[@]}"; do
	if ! test -f "${f_name}"; then
		FNOTFOUND+=("${f_name}")
	else
		FFOUND+=("${f_name}")
	fi
done

if [ ${#FNOTFOUND[@]} -ne 0 ]; then
	for f_name in "${FNOTFOUND[@]}"; do
		echo "${f_name} doesn't exist."
	done;
	echo Continue anyway? Press ENTER.
	read
fi

########################################################################
# Checking WAR file
echo
echo "The file you supplied is ${FULL_NAME}"
test -r "${FULL_NAME}" || (echo "File does not exist!!" && exit 1)
echo "Testing ${FULL_NAME} ... please hold the line ..."
unzip -t  ${FULL_NAME} > /dev/null 2>&1 || (echo "ERROR!! File is not a valid ZIP file!!" && exit 1) 
echo File seems valid ...

echo "Contents of ${APP_DIR} will be replaced with contets of this file."
echo "Press ENTER to start"
read
echo ... installing new WAR file!

TEMP_DIR=`mktemp -d`

########################################################################
# Make backup of file that need saving
echo "Saving files in current webapp directory:"
echo
for f_name in "${FFOUND[@]}"; do
	cp -vp "${f_name}" "${TEMP_DIR}"
done

########################################################################
# stop tomcat
if systemctl is-active --quiet tomcat9.service; then
	echo
	echo "Tomcat is running."
	echo "Stopping tomcat ..." 
	systemctl stop tomcat9.service
	echo
fi

########################################################################
# Installing WAR
echo
echo "Deleting old vmweb ..."
rm -rf  "${APP_DIR}"/*

echo "Deleting old logs and caches ..."
rm -rf "${CATALINA_BASE}"/logs/*
rm -rf "${CATALINA_BASE}"/temp/*
rm -rf "${CATALINA_BASE}"/work/*
echo
echo "Unzipping vmweb"
mkdir -p "${APP_DIR}"
(cd "${APP_DIR}"; unzip "${FULL_NAME}")
echo

########################################################################
# Bring saved files back
echo "Restoring saved files ..."
echo 
for f_name in "${FFOUND[@]}"; do
	cp -vp "${TEMP_DIR}/$(basename ${f_name})" "${f_name}"
done

########################################################################
# start tomcat
echo "Starting tomcat"
systemctl start tomcat9.service || echo "Starting tomcat failed!!"
########################################################################
# clean up
echo "Cleaning up ..."
echo
rm -rfv "${TEMP_DIR}"

echo "Done."

