# EC2 Access Recovery

In the event the access keys have been lost and an EC2 instance can no longer be accessed via SSH, this procedure will replace the instance's `authorized_keys` with a new key.

1. Create a Helper instance that we will mount the Lost instance's volume.
    * Be sure to select a subnet that is in the same availability zone as the Lost instance.
    * Do not use the same base image as it can lead to volume UUID clashes. e.g. if Amazon Linux is used for Lost instance, use Ubuntu for the Helper instance to ensure the Lost instance's volume can be successfully mounted on the Helper instance. If UUID's clash, the error message when mounting is not clear and it can be time consuming to troubleshoot. 
1. Create a new Key (e.g. `tools/generate-key-pair.sh replacement-key-pair`) and securely store the generated pem.
1. Stop the Lost instance.
1. Note Lost's volume Id (e.g. `vol-006601dac1b133a44`)
1. Detach Lost's volume.
1. Attach Lost's volume to Helper instance selecting an unused device path (e.g. `/dev/sdf`)
1. Create a mount target in `/mnt/lost_volume`
1. Mount using `mount /dev/sdf1 /mnt/lost_volume`
1. Navigate to /mnt/lost_volume/home/ec2_user/.ssh`
1. Replace the contents of `authorized_keys` with the Replacement Key's public key.
    * You may want to backup the existing authorized_keys by making a copy `cp authorized_keys authorized_keys.backup`
    * Get the public key from the `pem` using `ssh-keygen -l -f replacement-key-pair.pem`
1. Unmount using `umount /mnt/lost_volume`
1. In the AWS Console -> EC2 -> Volumes, select the Lost instance's volume and `Detach` it.
1. `Attach` the Lost instance's volume to the Lost instance, selecting `/dev/xvda` (root)
1. Start the Lost instance.
1. Verify you can now SSH into the instance, e.g. `ssh -i replacememnt-key-pair.pem ec2-user@ec2-3-94-204-237.compute-1.amazonaws.com`
    * This only works if the instance has a Security rule for allowing SSH (port 22) connections.