# Copyright © 2024 Joseph Wright <joseph@cloudboss.co>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

variable "ami" {
  type = object({
    filters = optional(list(object({
      name   = string
      values = list(string)
    })), [])
    most_recent = optional(bool, true)
    name        = optional(string, "")
    owner       = optional(string, "")
  })
  description = "An object to configure the AMI to use. One of filters or name must be set."

  default = {}
}

variable "block_device_mappings" {
  type = list(object({
    device_name = string
    ebs = optional(object({
      delete_on_termination = optional(bool, true)
      encrypted             = optional(bool, true)
      iops                  = optional(number, null)
      kms_key_id            = optional(string, null)
      snapshot_id           = optional(string, null)
      throughput            = optional(number, null)
      volume_size           = optional(number, null)
      volume_type           = optional(string, "gp3")
    }), null)
    no_device    = optional(bool, false)
    virtual_name = optional(string, null)
  }))
  description = "The block device mappings for the instances."

  default = []
}

variable "disable_api_stop" {
  type        = bool
  description = "Disable the ability to stop instances from the API."

  default = null
}

variable "disable_api_termination" {
  type        = bool
  description = "Disable the ability to terminate instances from the API."

  default = null
}

variable "extra_security_group_ids" {
  type        = list(string)
  description = "Additional security group IDs to attach to the instances."

  default = []
}

variable "health_check" {
  type = object({
    grace_period = optional(number, null)
    type         = optional(string, null)
  })
  description = "Configuration of the autoscaling health check."

  default = {}
}

variable "iam_instance_profile" {
  type        = string
  description = "The ARN or name of an instance profile to attach to the instances."

  default = ""
}

variable "imds_enabled" {
  type        = bool
  description = "Whether or not to enable the instance metadata service. If enabled, IMDSv2 is always enforced."

  default = true
}

variable "instance_initiated_shutdown_behavior" {
  type        = string
  description = "The behavior of instances when they are shut down. Must be stop or terminate."

  default = "stop"

  validation {
    condition     = contains(["stop", "terminate"], var.instance_initiated_shutdown_behavior)
    error_message = "Invalid instance initiated shutdown behavior: must be stop or terminate."
  }
}

variable "instance_refresh" {
  type = object({
    strategy = optional(string, null)
    preferences = optional(object({
      alarm_specification = optional(object({
        alarms = list(string)
      }), null)
      auto_rollback                = optional(bool, null)
      checkpoint_delay             = optional(string, null)
      checkpoint_percentages       = optional(list(number), null)
      instance_warmup              = optional(number, null)
      max_healthy_percentage       = optional(number, null)
      min_healthy_percentage       = optional(number, null)
      scale_in_protected_instances = optional(string, null)
      skip_matching                = optional(bool, null)
      standby_instances            = optional(string, null)
    }), null)
    triggers = optional(set(string), null)
  })
  description = "Configuration of instance refresh."

  default = null
}

variable "instance_type" {
  type        = string
  description = "The instance type to use for the autoscaling group. This is required if mixed_instances_overrides is not defined."

  default = null
}

variable "instances_desired" {
  type        = number
  description = "The initial number of instances desired. This value is ignored on Terraform updates to allow other processes to control it."

  default = null
}

variable "instances_max" {
  type        = number
  description = "The maximum number of instances in the autoscaling group."
}

variable "instances_min" {
  type        = number
  description = "The minimum number of instances in the autoscaling group."
}

variable "max_instance_lifetime" {
  type        = number
  description = "The maximum lifetime of instances in seconds."

  default = null
}

variable "mixed_instances_distribution" {
  type = object({
    on_demand_allocation_strategy            = optional(string, null)
    on_demand_base_capacity                  = optional(number, null)
    on_demand_percentage_above_base_capacity = optional(number, null)
    spot_allocation_strategy                 = optional(string, null)
    spot_instance_pools                      = optional(number, null)
    spot_max_price                           = optional(number, null)
  })
  description = "Configuration of mixed instance distribution."

  default = {}
}

variable "mixed_instances_overrides" {
  type = list(object({
    instance_requirements = optional(object({
      accelerator_count = optional(object({
        max = optional(number, null)
        min = optional(number, null)
      }), null)
      accelerator_manufacturers = optional(list(string), null)
      accelerator_names         = optional(list(string), null)
      accelerator_total_memory_mib = optional(object({
        max = optional(number, null)
        min = optional(number, null)
      }), null)
      accelerator_types      = optional(list(string), null)
      allowed_instance_types = optional(list(string), null)
      bare_metal             = optional(string, null)
      baseline_ebs_bandwidth_mbps = optional(object({
        max = optional(number, null)
        min = optional(number, null)
      }), null)
      burstable_performance                                   = optional(string, null)
      cpu_manufacturers                                       = optional(list(string), null)
      excluded_instance_types                                 = optional(list(string), null)
      instance_generations                                    = optional(list(string), null)
      local_storage                                           = optional(string, null)
      local_storage_types                                     = optional(list(string), null)
      max_spot_price_as_percentage_of_optimal_on_demand_price = optional(number, null)
      memory_gib_per_vcpu = optional(object({
        max = optional(number, null)
        min = optional(number, null)
      }), null)
      memory_mib = object({
        max = optional(number, null)
        min = optional(number, null)
      })
      network_bandwidth_gbps = optional(object({
        max = optional(number, null)
        min = optional(number, null)
      }), null)
      network_interface_count = optional(object({
        max = optional(number, null)
        min = optional(number, null)
      }), null)
      on_demand_max_price_percentage_over_lowest_price = optional(number, null)
      require_hibernate_support                        = optional(bool, null)
      spot_max_price_percentage_over_lowest_price      = optional(number, null)
      total_local_storage_gb = optional(object({
        max = optional(number, null)
        min = optional(number, null)
      }), null)
      vcpu_count = optional(object({
        max = optional(number, null)
        min = optional(number, null)
      }), null)
    }), null)
    instance_type     = optional(string, null)
    weighted_capacity = optional(number, null)
  }))
  description = "Configuration of mixed instance overrides."

  default = []
}

variable "monitoring_enabled" {
  type        = bool
  description = "Whether or not detailed monitoring is enabled."

  default = false
}
variable "capacity_rebalance" {
  type        = bool
  description = "Whether or not to enable capacity rebalancing."

  default = null
}

variable "name" {
  type        = string
  description = "The name of the autoscaling group and launch template."
}

variable "network_interfaces" {
  type = list(object({
    associate_carrier_ip_address = optional(bool, null)
    associate_public_ip_address  = optional(bool, null)
    delete_on_termination        = optional(bool, null)
    description                  = optional(string, null)
    device_index                 = optional(number, null)
    interface_type               = optional(string, null)
    ipv4_address_count           = optional(number, null)
    ipv4_addresses               = optional(list(string), null)
    ipv4_prefix_count            = optional(number, null)
    ipv4_prefixes                = optional(list(string), null)
    ipv6_address_count           = optional(number, null)
    ipv6_addresses               = optional(list(string), null)
    ipv6_prefix_count            = optional(number, null)
    ipv6_prefixes                = optional(list(string), null)
    network_interface_id         = optional(string, null)
    network_card_index           = optional(number, null)
    private_ip_address           = optional(string, null)
    security_groups              = optional(list(string), null)
    subnet_id                    = optional(string, null)
  }))
  description = "Configuration of network interfaces for the instances."

  default = []
}

variable "security_group_ids" {
  type        = list(string)
  description = "IDs of security groups to attach to the instances."

  default = []
}

variable "service_linked_role_arn" {
  type        = string
  description = "ARN of a service linked role to use for the autoscaling group."

  default = null
}

variable "ssh_key" {
  type        = string
  description = "Name of SSH key to assign to the instances."

  default = null
}

variable "subnet_ids" {
  type        = list(string)
  description = "IDs of subnets to use for the instances."
}

variable "suspended_processes" {
  type        = list(string)
  description = "A list of processes to suspend for the autoscaling group."

  default = []
}

variable "tags" {
  type = object({
    autoscaling_group = optional(map(string), null)
    default           = optional(map(string), null)
    instance          = optional(map(string), null)
    launch_template   = optional(map(string), null)
    security_group    = optional(map(string), null)
  })
  description = "Tags to assign to resources. If only default is defined, it will be applied to all resources."

  default = {}
}

variable "target_group_arns" {
  type        = list(string)
  description = "A list of target group ARNs to associate with the autoscaling group."

  default = []
}

variable "termination_policies" {
  type        = list(string)
  description = "A list of termination policies to use for the autoscaling group."

  default = []
}

variable "user_data" {
  type = object({
    value         = optional(string, null)
    base64encoded = optional(bool, false)
  })
  description = "The user data to provide to the instances."

  default = {}
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC to use for the instances."
}
