#! /bin/bash
STAGELB=www-nwea-preprod
SYSDATE="$(date +"%y-%m-%d")"
MASTERAMI="${SYSDATE}.master"
SLAVEAMI="${SYSDATE}.slave"
STAGEINSTANCE="$(aws elb describe-load-balancers --load-balancer-name $STAGELB --query LoadBalancerDescriptions[*].Instances[*] --output text)"
SECONDS=0

echo The following script will do the following
echo 1 - query the $SYAGELB load balancer and get the instance ID of the server
echo 2 - create a new ami based on the ec2 instance
echo 3 - turn off rsync on the ec2 instance
echo 4 - create master ami from ec2 instance
echo 5 - renable rsync on the stage instace

echo STAGE 1
echo "Creating Slave AMI from" $STAGEINSTANCE
SLAVEAMI_ID="$(ec2-create-image $STAGEINSTANCE --name $SLAVEAMI --description "Delete_me" --region us-west-2 | sed -e 's/^.*ami/ami/')" 

echo "your AMI SLAVE is: "$SLAVEAMI_ID


aws ec2 wait --region us-west-2 image-available --image-ids $SLAVEAMI_ID
echo the slave ami: $SLAVEAMI is available
echo waiting 120 seconds.  hold tight.
secs=$((2 * 60))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
echo ....
echo Wait complete
echo STAGE 1 Complete
echo STAGE 2
echo ....
echo Building Master AMI


#Disable RSYNC on stage
RYSNCSTATUS="$(curl -s -k -H "Authorization: Basic bndlYS1hZG1pbjpSc3luY0lzQ29vbA==" "https://www-stage.nwea.org/synctool/index.cgi?format=text")" 
echo  Current RSYNC status is: $RYSNCSTATUS

while [ $RYSNCSTATUS =  "enabled" ]
do
	echo "turning off rsync on $STAGEINSTANCE"
	RYSNCSTATUS="$(curl -s -k -H "Authorization: Basic  bndlYS1hZG1pbjpSc3luY0lzQ29vbA==" "https://www-stage.nwea.org/synctool/index.cgi?toggle=0&format=text&submit=1")"
        echo RSYNC is now : $RYSNCSTATUS 
done	
#
#
MASTERAMI_ID="$(ec2-create-image $STAGEINSTANCE --name $MASTERAMI --description "Delete_me" --region us-west-2 | sed -e 's/^.*ami/ami/')"

echo "your AMI master is: "$MASTERAMI_ID
aws ec2 wait --region us-west-2 image-available --image-ids $MASTERAMI_ID
echo "Master ami: $MASTERAMI is avialable"
#
#
#
# Renable RSYNC on Stage
RYSNCSTATUS="$(curl -s -k -H "Authorization: Basic bndlYS1hZG1pbjpSc3luY0lzQ29vbA==" "https://www-stage.nwea.org/synctool/index.cgi?format=text")"
echo  Current RSYNC status is: $RYSNCSTATUS

while [ $RYSNCSTATUS =  "disabled" ]
do
        echo "turning ON rsync on $STAGEINSTANCE"
        RYSNCSTATUS="$(curl -s -k -H "Authorization: Basic  bndlYS1hZG1pbjpSc3luY0lzQ29vbA==" "https://www-stage.nwea.org/synctool/index.cgi?toggle=1&format=text&submit=1")"
        echo RSYNC is now : $RYSNCSTATUS 
done



duration=$SECONDS
echo "$(($duration / 60)) minutes and $(($duration % 60)) seconds elapsed."


