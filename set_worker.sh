scp -i $2 -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=60" /home/ubuntu/worker.py ubuntu@$1:/home/ubuntu/worker.py
ssh -i $2 -o "StrictHostKeyChecking=no" -o "ConnectionAttempts=10" ubuntu@$1 <<EOF
    export REDIS_HOST=$REDIS_HOST
    sudo apt update
    sudo apt install python3-rq -y
    python3 worker.py
    exit
EOF

