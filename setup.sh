# debug
# set -o xtrace

KEY_NAME="cloud-course-`date +'%N'`"
KEY_PEM="$KEY_NAME.pem"

echo "create key pair $KEY_PEM to connect to instances and save locally"
aws ec2 create-key-pair --key-name $KEY_NAME \
    | jq -r ".KeyMaterial" > $KEY_PEM

# secure the key pair
chmod 400 $KEY_PEM

SEC_GRP="my-sg-`date +'%N'`"

echo "setup firewall $SEC_GRP"
aws ec2 create-security-group   \
    --group-name $SEC_GRP       \
    --description "Access my instances"

# figure out my ip
MY_IP=$(curl ipinfo.io/ip)
echo "My IP: $MY_IP"


echo "setup rule allowing SSH access to $MY_IP only"
aws ec2 authorize-security-group-ingress        \
    --group-name $SEC_GRP --port 22 --protocol tcp \
    --cidr $MY_IP/32

aws ec2 authorize-security-group-ingress        \
    --group-name $SEC_GRP --source-group $SEC_GRP --protocol all

echo "setup rule allowing HTTP (port 5000) access to $MY_IP only"
aws ec2 authorize-security-group-ingress        \
    --group-name $SEC_GRP --port 5000 --protocol tcp \
    --cidr $MY_IP/32

UBUNTU_20_04_AMI="ami-042e8287309f5df03"

echo "Creating Ubuntu 20.04 instance..."
RUN_INSTANCES=$(aws ec2 run-instances   \
    --image-id $UBUNTU_20_04_AMI        \
    --count 2 \
    --instance-type t3.micro            \
    --key-name $KEY_NAME                \
    --security-groups $SEC_GRP)

APP_INSTANCE_ID=$(echo $RUN_INSTANCES | jq -r '.Instances[0].InstanceId')
REDIS_INSTANCE_ID=$(echo $RUN_INSTANCES | jq -r '.Instances[1].InstanceId')

echo $APP_INSTANCE_ID
echo $REDIS_INSTANCE_ID

echo "Waiting for instance creation..."
aws ec2 wait instance-running --instance-ids $APP_INSTANCE_ID $REDIS_INSTANCE_ID


APP_PUBLIC_IP=$(aws ec2 describe-instances  --instance-ids $APP_INSTANCE_ID |
    jq -r '.Reservations[0].Instances[0].PublicIpAddress'
)

REDIS_PUBLIC_IP=$(aws ec2 describe-instances  --instance-ids $REDIS_INSTANCE_ID |
    jq -r '.Reservations[0].Instances[0].PublicIpAddress'
)

echo "New instance $APP_INSTANCE_ID @ $APP_PUBLIC_IP"
echo "New instance $REDIS_INSTANCE_ID @ $REDIS_PUBLIC_IP"

echo "setup redis"
ssh -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=60" ubuntu@$REDIS_PUBLIC_IP <<EOF
    sudo apt update
    sudo apt install redis-tools redis-server -y
    sudo sed -i "s/bind 127.0.0.1 ::1/bind 0.0.0.0 ::1/g" /etc/redis/redis.conf
    # run app
    sudo systemctl restart redis-server
    exit
EOF

echo "deploying code to production"
scp -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=60" /templates ubuntu@$APP_PUBLIC_IP:/home/ubuntu/
scp -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=60" auto_scale.py ubuntu@$APP_PUBLIC_IP:/home/ubuntu/
scp -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=60" set_worker.sh ubuntu@$APP_PUBLIC_IP:/home/ubuntu/
scp -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=60" worker.py ubuntu@$APP_PUBLIC_IP:/home/ubuntu/


echo "setup production environment"
ssh -i $KEY_PEM -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=10" ubuntu@$APP_PUBLIC_IP <<EOF
    export REDIS_HOST=$REDIS_PRIVATE_IP
    sudo apt update
    sudo apt install python3-flask -y
    sudo apt install python3-boto3 -y
    # run app
    nohup flask run --host 0.0.0.0  &>/dev/null &
    cd /home/ubuntu/
    ls
    exit
EOF


echo "test that it all worked"
curl  --retry-connrefused --retry 10 --retry-delay 1  http://$PUBLIC_IP:5000