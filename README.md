# asg

A Terraform module to create an autoscaling group and launch template.

## Example

```
module "asg" {
  source  = "cloudboss/asg/aws"
  version = "x.x.x"

  ami = {
    name = var.ami_name
  }
  block_device_mappings = [
    {
      device_name = local.device
      ebs = {
        iops        = var.volume.iops
        kms_key_id  = var.volume.kms_key_id
        volume_size = var.volume.size
        volume_type = var.volume.type
      }
    },
  ]
  instance_refresh = {
    strategy = "Rolling"
  }
  instances_desired    = 2
  instances_max        = 10
  instances_min        = 2
  instance_type        = "m5.large"
  iam_instance_profile = module.iam_role.instance_profile.arn
  name                 = var.name
  security_group_ids   = var.security_group_ids
  ssh_key              = var.ssh_key
  subnet_ids           = var.subnet_ids
  tags = {
    default = var.tags
  }
  user_data = {
    value = module.user_data.value
  }
  vpc_id = var.vpc_id
}
```
