#!/bin/bash -e

set -ex

j=$(om-linux -t https://$OPSMANIP -k -u $OPSMAN_USERNAME -p $OPSPW curl -s -p "/api/v0/staged/products/")
mysql=$(jq -r '.[].guid' <<< $j | grep -iw "p-mysql-*")

j=$(om-linux -t https://$OPSMANIP -k -u $OPSMAN_USERNAME -p $OPSPW curl -s -p "/api/v0/staged/products/")
director=$(jq -r '.[].guid' <<< $j | grep -iw "p-bosh*")

j=$(om-linux -t https://$OPSMANIP -k -u $OPSMAN_USERNAME -p $OPSPW curl -s -p "/api/v0/deployed/products/$director/static_ips/")
dirip=$(jq -r '.[].ips' <<< $j | grep '[\d+\.\d+\.\d+\.\d+]')

j=$(om-linux -t https://$OPSMANIP -k -u $OPSMAN_USERNAME -p $OPSPW curl -s -p "/api/v0/security/root_ca_certificate") &> /dev/null
cert=$(jq -r '.root_ca_certificate_pem' <<< $j)

#echo "$cert" >> root_ca_pem
#echo root_ca_pem created

mv boshv2-cli/bosh-cli-* boshv2-cli/bosh
chmod 755 boshv2-cli/bosh

#export BOSH_CLIENT=$BOSH_CLIENT
#export BOSH_CLIENT_SECRET=$BOSH_CLIENT_SECRET
export BOSH_CA_CERT=$cert

boshv2-cli/bosh -e $dirip -d $mysql run-errand smoke-tests
