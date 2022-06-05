from rq import Queue
import os
import boto3

scaleup_number = 80
scaledown_number = 15
worker_max = 30

def scale(q: Queue, instances_list):
    if len(q)==0:
        set_key()
    if len(q) >= scaleup_number and worker_max > len(instances_list):
        upscale(instances_list)
    if (len(q) <= scaledown_number and len(instances_list) > 1):
        downscale(instances_list)


def set_key():
    ec2 = boto3.resource('ec2')
    key_path = "/home/ubuntu/key.pem"
    keypair = ec2.create_key_pair(KeyName='Key_scale')
    private_key_file = open(key_path, "w")
    private_key_file.write(keypair.key_material)
    private_key_file.close()
    command = "chmod 400 {}".format(key_path)
    os.system(command)

def get_sec_group():
    filters = [
    {
    'Name': 'instance-state-name',
    'Values': ['running']
    }
    ]

    for x in boto3.resource('ec2').instances.filter(Filters=filters).limit(1):
        security_group = x.security_groups[0]['GroupName']
    return [security_group]

def upscale(instances_list):
    key_path = "/home/ubuntu/key.pem"
    ec2 = boto3.resource('ec2')
    instances = ec2.create_instances(
        ImageId="ami-042e8287309f5df03",
        MinCount=1,
        MaxCount=1,
        InstanceType="t3.micro",
        KeyName="Key_scale",
        SecurityGroups = get_sec_group()
    )
    instances[0].wait_until_running()
    command = "bash/home/ubuntu/set_worker.sh {} {}".format(instances[0].private_ip_address, key_path)
    os.system(command)
    instances_list.append(instances[0])


def downscale(instances_list):
    instance = instances_list.pop(len(instances_list) - 1)
    instance.terminate()
