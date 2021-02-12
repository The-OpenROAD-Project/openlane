#!/bin/bash
# Copyright 2020 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
echo "Checking If I Should Delete The Docker Image..."
echo "BRANCH: $BRANCH_NAME"
echo "IMAGE NAME: $IMAGE_NAME"
DOCKERHUB_USER=$1
DOCKERHUB_PASSWORD=$2
if [[ $GITHUB_EVENT_NAME == "pull_request" ]]; then
    export ORGANIZATION=agorararmard
    export REPOSITORY=openlane
    export TAG=$BRANCH_NAME-pull_request-$PULL_REQUEST_ID-$COMMIT_SHA_5
    sudo apt update
    sudo apt install jq
    HUB_TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${DOCKERHUB_USER}'", "password": "'${DOCKERHUB_PASSWORD}'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)
    curl -i -X DELETE \
        -H "Accept: application/json" \
        -H "Authorization: JWT $HUB_TOKEN" \
        https://hub.docker.com/v2/repositories/$ORGANIZATION/$REPOSITORY/tags/${TAG}/  > /dev/null 2>&1
else
    echo "IMAGE $IMAGE_NAME won't be deleted."
fi

exit 0
