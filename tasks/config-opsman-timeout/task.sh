#!/bin/bash
apt-get update 
apt-get install ssh expect curl -y

/usr/bin/expect << EOD
set timeout 50
spawn ssh -o "StrictHostKeyChecking=no" ubuntu@$OPSMANIP

expect "*assword:"
send "$OPSPW\r";
expect "*$\*"
send "sudo su -\r";
expect "*ubuntu:"
send "$OPSPW\r";
expect "*~#"
send "sed -i 's/1800/6000/g' /home/tempest-web/tempest/web/config/thin.production.yml\r";
expect "*~#"
send "exit\r";
EOD

/usr/bin/expect << EOD
set timeout 50
spawn ssh -o "StrictHostKeyChecking=no" ubuntu@$OPSMANIP

expect "*assword:"
send "$OPSPW\r";
expect "*$\*"
send "sudo reboot\r";
expect "*ubuntu:"
send "$OPSPW\r";
expect "*$"
EOD

  
printf "Waiting for %s to come up" "$OPSMAN_URI"
  until $(curl --output /dev/null --silent --head --fail -k https://${OPSMAN_URI}); do
    printf '.'
    sleep 5
  done
printf '\n'

curl -k "https://$OPSMAN_URI/api/v0/unlock" \
     -X PUT \
     -H "Content-Type: application/json" \
     -d '{"passphrase" : '"\"$OPSMAN_PASSPHRASE\""'}'
