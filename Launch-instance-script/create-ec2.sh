#!/bin/bash

##### Change these values ###
ZONE_ID="Z078807431WCP5BA26ASG"
SG_NAME="allow-all-to-public"
IAM_INSTANCE_PROFILE="Arn=arn:aws:iam::645019601948:instance-profile/role-for-aws-secret-manager-roboshop-components"
#############################


if [ -z "${1}" ]; then
  ENV=""
else
  ENV="-$1"
fi
COMPONENT=all
create_ec2() {
  PRIVATE_IP=$(aws ec2 run-instances \
      --image-id ${AMI_ID} \
      --instance-type t3.micro \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${COMPONENT}${ENV}]" \
      --instance-market-options "MarketType=spot,SpotOptions={SpotInstanceType=persistent,InstanceInterruptionBehavior=stop}"\
      --security-group-ids ${SGID} \
      --iam-instance-profile="${IAM_INSTANCE_PROFILE}" \
      | jq '.Instances[].PrivateIpAddress' | sed -e 's/"//g')

  sed -e "s/IPADDRESS/${PRIVATE_IP}/" -e "s/COMPONENT/${COMPONENT}/" route53.json >/tmp/record.json
  aws route53 change-resource-record-sets --hosted-zone-id ${ZONE_ID} --change-batch file:///tmp/record.json | jq
}

#AMI_ID=$(aws ec2 describe-images --filters "Name=name,Values=Centos-7-DevOps-Practice" | jq '.Images[].ImageId' | sed -e 's/"//g')
AMI_ID="ami-0408d6aa07d74894b"
SGID=$(aws ec2 describe-security-groups --filters Name=group-name,Values=${SG_NAME} | jq  '.SecurityGroups[].GroupId' | sed -e 's/"//g')

if [ "$COMPONENT" == "all" ]; then
  for component in catalogue cart dispatch user shipping payment frontend mongodb mysql rabbitmq redis ; do
    COMPONENT=$component
    create_ec2
  done
else
  create_ec2
fi