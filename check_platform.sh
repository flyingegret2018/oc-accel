#!/bin/bash
##
## Copyright 2019 International Business Machines
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##

if [[ -z ${SNAP_ROOT} ]]; then
    echo "err: SNAP_ROOT not set!"
    exit 1
fi

SNAP_MAINT="${SNAP_ROOT}/software/tools/snap_maint"

# echo -n "Checking ${SNAP_MAINT} ... "
if [ ! -x ${SNAP_MAINT} ]; then
    # echo "Not build yet!"
    exit 0
fi
# echo "OK"

# Software seems to be build, check if it is properly executable
# echo -n "Trying out ${SNAP_MAINT} ... "
error=0
${SNAP_MAINT} -h &> /dev/null || error=1
if [ $error -eq 1 ]; then
    # echo "Not executable!"
    exit 1
fi
# echo "OK"

exit 0
