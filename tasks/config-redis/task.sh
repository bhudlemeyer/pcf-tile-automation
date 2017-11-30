#!/bin/bash -e

set -x

#mv tool-om/om-linux-* tool-om/om-linux
chmod +x tool-om/om-linux
CMD=./tool-om/om-linux

RELEASE=`$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k available-products | grep p-redis`

PRODUCT_NAME=`echo $RELEASE | cut -d"|" -f2 | tr -d " "`
PRODUCT_VERSION=`echo $RELEASE | cut -d"|" -f3 | tr -d " "`

$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k stage-product -p $PRODUCT_NAME -v $PRODUCT_VERSION

function fn_other_azs {
  local azs_csv=$1
  echo $azs_csv | awk -F "," -v braceopen='{' -v braceclose='}' -v name='"name":' -v quote='"' -v OFS='"},{"name":"' '$1=$1 {print braceopen name quote $0 quote braceclose}'
}

OTHER_AZS=$(fn_other_azs $OTHER_JOB_AZS)

NETWORK=$(cat <<-EOF
{
  "singleton_availability_zone": {
    "name": "$SINGLETON_JOB_AZ"
  },
  "other_availability_zones": [
    $OTHER_AZS
  ],
  "network": {
    "name": "$NETWORK_NAME"
  },
  "service_network": {
    "name": "$SERVICE_NETWORK"
  }
}
EOF
)

PROPERTIES=$(cat <<-EOF
{
    ".redis-on-demand-broker.service_instance_limit": {
      "value": 0
    },
    ".properties.metrics_polling_interval": {
      "value": 30
    },
    ".properties.small_plan_selector": {
       "value": "$SMALL_PLAN_STATUS"
    },
    ".properties.medium_plan_selector": {
      "value": "$MEDIUM_PLAN_STATUS"
    },
    ".properties.large_plan_selector": {
      "value": "$LARGE_PLAN_STATUS"
    },
    ".properties.backups_selector": {
      "value": "No Backups"
    }
}
EOF
)

RESOURCES=$(cat <<-EOF
{
  "redis-on-demand-broker": {
    "instance_type": {"id": "automatic"},
    "instances" : $ONDEMAND_BROKER_INSTANCES
  }
}
EOF
)

echo "Saving properties for minimum valuable configuration"

$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k configure-product -n $PRODUCT_NAME -p "$PROPERTIES" -pn "$NETWORK" -pr "$RESOURCES"


if [[ "$SYSLOG_SELECTOR" == "Yes without encryption" ]]; then
SYSLOG_PROPS=$(cat <<-EOF
{
    ".properties.syslog_selector": {
      "value": "$SYSLOG_SELECTOR"
    },
    ".properties.syslog_selector.active.syslog_transport": {
      "value": "$SYSLOG_PROTOCOL"
    },
    ".properties.syslog_selector.active.syslog_address": {
      "value": "$SYSLOG_HOST"
    },
    ".properties.syslog_selector.active.syslog_port": {
      "value": $SYSLOG_PORT
    }
}
EOF
)

else
SYSLOG_PROPS=$(cat <<-EOF
{
    ".properties.syslog_selector": {
      "value": "No"
    }
}
EOF
)
fi

echo "Applying syslog settings..."
$CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k configure-product -n $PRODUCT_NAME -p "$SYSLOG_PROPS"


if [[ "$BACKUPS_SELECTOR" == "S3 Backups" ]]; then
  BACKUPS_PROPS=$(cat <<-EOF
  {
      ".properties.backups_selector": {
        "value": "$BACKUPS_SELECTOR"
      },
      ".properties.backups_selector.s3.access_key_id": {
        "value": "$S3_ACCESS_KEY"
      },
      ".properties.backups_selector.s3.secret_access_key": {
        "value": "$S3_SECRET_KEY"
      },
      ".properties.backups_selector.s3.endpoint_url": {
        "value": "$S3_ENDPOINT"
      },
      ".properties.backups_selector.s3.signature_version": {
        "value": "$S3_SIGNATURE"
      },
      ".properties.backups_selector.s3.bucket_name": {
        "value": "$S3_BUCKET"
      },
      ".properties.backups_selector.s3.path": {
        "value": "$S3_PATH"
      },
      ".properties.backups_selector.s3.cron_schedule": {
        "value": "$S3_SCHEDULE"
      }
  }
EOF
)
  echo "Applying backups settings..."
  $CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k configure-product -n $PRODUCT_NAME -p "$BACKUPS_PROPS"
fi

if [[ -z "$ERRANDS_TO_DISABLE" ]] || [[ "$ERRANDS_TO_DISABLE" == "none" ]]; then
  echo "No post-deploy errands to disable"
else
  enabled_errands=$(
  $CMD -t https://${OPS_MGR_HOST} -u $OPS_MGR_USR -p $OPS_MGR_PWD -k errands --product-name $PRODUCT_NAME |
  tail -n+4 | head -n-1 | grep -v false | cut -d'|' -f2 | tr -d ' '
  )
  if [[ "$ERRANDS_TO_DISABLE" == "all" ]]; then
    errands_to_disable="${enabled_errands[@]}"
  else
    errands_to_disable=$(echo "$ERRANDS_TO_DISABLE" | tr ',' '\n')
  fi
  
  will_disable=$(for i in $enabled_errands; do
      for j in $errands_to_disable; do
        if [ $i == $j ]; then
          echo $j
        fi
      done
    done
  )

  if [ -z "$will_disable" ]; then
    echo "All errands are already disable that were requested"
  else
    while read errand; do
      echo -n Disabling $errand...
      $CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k set-errand-state --product-name $PRODUCT_NAME --errand-name $errand --post-deploy-state "disabled"
      echo done
    done < <(echo "$will_disable")
  fi
fi

if [[ -z "$ERRANDS_TO_WHENCHANGED" ]] || [[ "$ERRANDS_TO_WHENCHANGED" == "none" ]]; then
  echo "No post-deploy errands to set to when-changed"
else
  enabled_errands=$(
  $CMD -t https://${OPS_MGR_HOST} -u $OPS_MGR_USR -p $OPS_MGR_PWD -k errands --product-name $PRODUCT_NAME |
  tail -n+4 | head -n-1 | grep -v false | cut -d'|' -f2 | tr -d ' '
  )
  if [[ "$ERRANDS_TO_WHENCHANGED" == "all" ]]; then
    errands_to_whenchanged="${enabled_errands[@]}"
  else
    errands_to_whenchanged=$(echo "$ERRANDS_TO_WHENCHANGED" | tr ',' '\n')
  fi
  
  will_whenchanged=$(for i in $enabled_errands; do
      for j in $errands_to_whenchanged; do
        if [ $i == $j ]; then
          echo $j
        fi
      done
    done
  )

  if [ -z "$will_whenchanged" ]; then
    echo "All errands are already set to when changed that were requested"
  else
    while read errand; do
      echo -n Disabling $errand...
      $CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k set-errand-state --product-name $PRODUCT_NAME --errand-name $errand --post-deploy-state "when-changed"
      echo done
    done < <(echo "$will_whenchanged")
  fi
fi

if [[ -z "$PREDELETE_ERRANDS_TO_DISABLE" ]] || [[ "$PREDELETE_ERRANDS_TO_DISABLE" == "none" ]]; then
  echo "No pre-delete errands to disable"
else
  enabled_errands=$(
  $CMD -t https://${OPS_MGR_HOST} -u $OPS_MGR_USR -p $OPS_MGR_PWD -k errands --product-name $PRODUCT_NAME |
  tail -n+4 | head -n-1 | grep -v false | cut -d'|' -f2 | tr -d ' '
  )
  if [[ "$PREDELETE_ERRANDS_TO_DISABLE" == "all" ]]; then
    errands_to_disable="${enabled_errands[@]}"
  else
    errands_to_disable=$(echo "$PREDELETE_ERRANDS_TO_DISABLE" | tr ',' '\n')
  fi
  
  will_disable=$(for i in $enabled_errands; do
      for j in $errands_to_disable; do
        if [ $i == $j ]; then
          echo $j
        fi
      done
    done
  )

  if [ -z "$will_disable" ]; then
    echo "All errands are already disable that were requested"
  else
    while read errand; do
      echo -n Disabling $errand...
      $CMD -t https://$OPS_MGR_HOST -u $OPS_MGR_USR -p $OPS_MGR_PWD -k set-errand-state --product-name $PRODUCT_NAME --errand-name $errand --pre-delete-state "disabled"
      echo done
    done < <(echo "$will_disable")
  fi
fi
