#!/bin/bash -eu

# Copyright 2017-Present Pivotal Software, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

cf api $CF_API_URI --skip-ssl-validation
cf auth $CF_USERNAME $CF_PASSWORD

echo creating  ${DEMO_ORG}...
cf create-org $DEMO_ORG 

echo creating demo space ${DEMO_SPACE}...
cf t -o $DEMO_ORG
cf create-space $DEMO_SPACE

echo creating demo user ${DEMO_USER}
cf t -o $DEMO_ORG -s $DEMO_SPACE
cf create-user $DEMO_USER $DEMO_PW
cf set-org-role $DEMO_USER $DEMO_ORG OrgManager
cf set-space-role $DEMO_USER $DEMO_ORG $DEMO_SPACE SpaceManager
cf set-space-role $DEMO_USER $DEMO_ORG $DEMO_SPACE SpaceDeveloper

