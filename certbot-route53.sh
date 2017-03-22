#!/bin/sh

if [ -z $CERTBOT_DOMAIN ]; then
  mkdir -p $PWD/letsencrypt

  certbot certonly \
    --non-interactive \
    --manual \
    --manual-auth-hook $PWD/$0 \
    --manual-cleanup-hook $PWD/$0 \
    --preferred-challenge dns \
    --config-dir $PWD/letsencrypt \
    --work-dir $PWD/letsencrypt \
    --logs-dir $PWD/letsencrypt \
    $@

else
  [[ $CERTBOT_AUTH_OUTPUT ]] && ACTION="DELETE" || ACTION="UPSERT"

  QUERY='HostedZones[?ends_with(`'"$CERTBOT_DOMAIN."'`,Name)].Id'

  HOSTED_ZONE_ID=$(aws route53 list-hosted-zones --query $QUERY --output text)

  if [ -z $HOSTED_ZONE_ID ]; then
    echo "No hosted zone found that matches $CERTBOT_DOMAIN"
    exit 1
  fi

  aws route53 wait resource-record-sets-changed --id $(
    aws route53 change-resource-record-sets \
    --hosted-zone-id $HOSTED_ZONE_ID \
    --query ChangeInfo.Id --output text \
    --change-batch "{
      \"Changes\": [{
        \"Action\": \"$ACTION\",
        \"ResourceRecordSet\": {
          \"Name\": \"_acme-challenge.$CERTBOT_DOMAIN.\",
          \"ResourceRecords\": [{\"Value\": \"\\\"$CERTBOT_VALIDATION\\\"\"}],
          \"Type\": \"TXT\",
          \"TTL\": 30
        }
      }]
    }"
  )
  
  echo 1
fi
