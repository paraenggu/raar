#!/bin/bash
################################################################################
# raar-record-handler.sh - Moves new recordings to the raar import directory
################################################################################
#
# Copyright (C) 2018 Radio Bern RaBe
#                    Switzerland
#                    http://www.rabe.ch
#
# This program is free software: you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public 
# License as published  by the Free Software Foundation, version
# 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public
# License  along with this program.
# If not, see <http://www.gnu.org/licenses/>.
#
# Please submit enhancements, bugfixes or comments via:
# https://github.com/radiorabe/raar
#
# Authors:
#  Christian Affolter <c.affolter@purplehaze.ch>
#
# Description:
# This script uses inotifywatch to listen for a close_write event on a given
# watch directory, containing recording files. The script assumes, that a
# recording has finished on such an event and moves the file to the given
# destination directory.
# If the archival was successful, the script sends the last successful
# recording timestamp to a Zabbix monitoring system with the help of the
# zabbix_sender tool.
# The script is intended to be used together with the rotter recording tool
# and RAAR.
#
# Usage:
# raar-record-handler.sh <WATCH-DIRECTORY> <DESTINATION-DIRECTORY>
#

watchDir="$1"
destDir="$2"

if test -z "${watchDir}"; then
    echo "Missing watch directory as the first parameter" >&2
    exit 1
fi

if ! test -d "${watchDir}"; then
    echo "Watch directory does not exist" >&2
    exit 2
fi

if test -z "${destDir}"; then
    echo "Missing destination directory as the second parameter" >&2
    exit 1
fi

if ! test -d "${destDir}"; then
    echo "Destination directory does not exist" >&2
    exit 2
fi

echo "Watching for new records in ${watchDir}"
echo "Recordings will be moved to ${destDir}"

# The minimum size a recording must have to trigger an archival
minFileSize="$(( 20 * 1048576 ))" # 20 MiB

inotifywait --monitor --event close_write "${watchDir}" | while read \
    watchedFileName eventNames eventFileName
do
    echo "${eventNames} occoured on ${eventFileName}"

    sourcePath="${watchDir}/${eventFileName}"

    # Skip recordings with a file size lower than $minFileSize
    # This prevents the first close_write event on initial flac or vorbis files
    # from triggering an archival, even though the recording has just started
    # https://github.com/njh/rotter/issues/35#issuecomment-362905991
    test $(stat --printf="%s" "${sourcePath}") -lt ${minFileSize} && continue

    echo "Archiving ${eventFileName}"

    tmpPath="${destDir}/.${eventFileName}.tmp"
    destPath="${destDir}/${eventFileName}"

    # Move the file to a temporary location in a first step. This prevents the
    # archive from importing an unfinished file, in case the source and
    # destination are located on different file systems (which leads to a copy
    # instead of a move operation)
    echo "Moving ${sourcePath} to ${tmpPath}"
    if ! mv "${sourcePath}" "${tmpPath}"; then
        echo "Moving ${sourcePath} to ${tmpPath} failed" >&2
        continue
    fi

    echo "Moving ${tmpPath} to ${destPath}"
    if ! mv "${tmpPath}" "${destPath}"; then
        echo "Moving ${tmpPath} to ${destPath} failed" >&2
        continue
    fi

    echo "${eventFileName} successfully archived"

    # Inform the monitoring system about the last successfull recording
    zabbix_sender --config /etc/zabbix/zabbix_agentd.conf \
                  --key 'rabe.raar.recording.success[]' \
                  --value "$(date +%s)" > /dev/null
done
