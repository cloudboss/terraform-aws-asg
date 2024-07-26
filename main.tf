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

locals {
  ami_filters_computed = [
    {
      name   = "name"
      values = [var.ami.name]
    }
  ]
  ami_filters = (
    length(var.ami.filters) > 0
    ? var.ami.filters
    : local.ami_filters_computed
  )
  ami_owner_default = data.aws_caller_identity.me.account_id
  ami_owner = (
    length(var.ami.owner) > 0 ? var.ami.owner : local.ami_owner_default
  )

  instance_profile_arn = (
    startswith(var.iam_instance_profile, "arn:") ? var.iam_instance_profile : null
  )
  instance_profile_name = (
    startswith(var.iam_instance_profile, "arn:") ? null : var.iam_instance_profile
  )

  vpc_security_group_ids = (
    length(var.network_interfaces) == 0 ? var.security_group_ids : null
  )

  tags_autoscaling_group      = merge(var.tags.default, var.tags.autoscaling_group)
  tags_instance               = merge({ Name = var.name }, var.tags.default, var.tags.instance)
  tags_launch_template_merged = merge(var.tags.default, var.tags.launch_template)
  tags_launch_template = (
    length(local.tags_launch_template_merged) > 0
    ? local.tags_launch_template_merged
    : null
  )
  tags_security_group_merged = merge(var.tags.default, var.tags.security_group)
  tags_security_group = (
    length(local.tags_security_group_merged) > 0
    ? local.tags_security_group_merged
    : null
  )

  user_data = try(
    var.user_data.base64encoded
    ? var.user_data.value
    : base64encode(var.user_data.value), null
  )
}

data "aws_caller_identity" "me" {}

data "aws_ami" "it" {
  most_recent = var.ami.most_recent
  owners      = [local.ami_owner]

  dynamic "filter" {
    for_each = local.ami_filters
    content {
      name   = filter.value.name
      values = filter.value.values
    }
  }
}

resource "terraform_data" "ami_validate" {
  lifecycle {
    precondition {
      condition = anytrue([
        length(var.ami.name) > 0,
        length(var.ami.filters) > 0,
      ])
      error_message = "One of var.ami.name or var.ami.filters must be defined."
    }
  }
}

resource "terraform_data" "instance_validate" {
  lifecycle {
    precondition {
      condition = anytrue([
        var.instance_type != null,
        length(var.mixed_instances_overrides) != 0,
      ])
      error_message = "One of var.instance_type or var.instance_requirements must be defined."
    }
  }
}

resource "aws_launch_template" "it" {
  disable_api_stop                     = var.disable_api_stop
  disable_api_termination              = var.disable_api_termination
  image_id                             = data.aws_ami.it.id
  instance_initiated_shutdown_behavior = var.instance_initiated_shutdown_behavior
  instance_type                        = var.instance_type
  key_name                             = var.ssh_key
  name                                 = var.name
  tags                                 = local.tags_launch_template
  user_data                            = local.user_data
  vpc_security_group_ids               = local.vpc_security_group_ids

  metadata_options {
    http_endpoint      = var.imds_enabled ? "enabled" : "disabled"
    http_tokens        = "required"
    http_protocol_ipv6 = "enabled"
  }

  monitoring {
    enabled = var.monitoring_enabled
  }

  dynamic "block_device_mappings" {
    for_each = var.block_device_mappings
    iterator = each
    content {
      device_name  = each.value.device_name
      no_device    = each.value.no_device
      virtual_name = each.value.virtual_name

      dynamic "ebs" {
        for_each = each.value.ebs == null ? [] : [1]
        content {
          delete_on_termination = each.value.ebs.delete_on_termination
          encrypted             = each.value.ebs.encrypted
          iops                  = each.value.ebs.iops
          kms_key_id            = each.value.ebs.kms_key_id
          snapshot_id           = each.value.ebs.snapshot_id
          throughput            = each.value.ebs.throughput
          volume_size           = each.value.ebs.volume_size
          volume_type           = each.value.ebs.volume_type
        }
      }
    }
  }

  dynamic "iam_instance_profile" {
    for_each = length(var.iam_instance_profile) == 0 ? [] : [1]
    content {
      arn  = local.instance_profile_arn
      name = local.instance_profile_name
    }
  }

  dynamic "network_interfaces" {
    for_each = var.network_interfaces
    iterator = each
    content {
      associate_carrier_ip_address = each.value.associate_carrier_ip_address
      associate_public_ip_address  = each.value.associate_public_ip_address
      delete_on_termination        = each.value.delete_on_termination
      description                  = each.value.description
      device_index                 = each.value.device_index
      ipv4_address_count           = each.value.ipv4_address_count
      ipv4_addresses               = each.value.ipv4_addresses
      ipv4_prefix_count            = each.value.ipv4_prefix_count
      ipv4_prefixes                = each.value.ipv4_prefixes
      ipv6_address_count           = each.value.ipv6_address_count
      ipv6_addresses               = each.value.ipv6_addresses
      ipv6_prefix_count            = each.value.ipv6_prefix_count
      ipv6_prefixes                = each.value.ipv6_prefixes
      network_interface_id         = each.value.network_interface_id
      network_card_index           = each.value.network_card_index
      private_ip_address           = each.value.private_ip_address
      security_groups = (
        each.value.security_groups == null
        ? var.security_group_ids
        : each.value.security_groups
      )
      subnet_id = each.value.subnet_id
    }
  }

  dynamic "tag_specifications" {
    for_each = length(local.tags_instance) > 0 ? [1] : []
    content {
      resource_type = "instance"
      tags          = local.tags_instance
    }
  }
}

resource "aws_autoscaling_group" "it" {
  capacity_rebalance        = var.capacity_rebalance
  desired_capacity          = var.instances_desired
  health_check_grace_period = var.health_check.grace_period
  health_check_type         = var.health_check.type
  max_instance_lifetime     = var.max_instance_lifetime
  max_size                  = var.instances_max
  min_size                  = var.instances_min
  name                      = var.name
  service_linked_role_arn   = var.service_linked_role_arn
  suspended_processes       = var.suspended_processes
  target_group_arns         = var.target_group_arns
  termination_policies      = var.termination_policies
  vpc_zone_identifier       = var.subnet_ids

  dynamic "instance_refresh" {
    for_each = var.instance_refresh == null ? [] : [var.instance_refresh]
    content {
      strategy = instance_refresh.value.strategy
      triggers = instance_refresh.value.triggers

      dynamic "preferences" {
        for_each = (
          instance_refresh.value.preferences == null
          ? []
          : [instance_refresh.value.preferences]
        )
        content {
          auto_rollback                = preferences.value.auto_rollback
          checkpoint_delay             = preferences.value.checkpoint_delay
          checkpoint_percentages       = preferences.value.checkpoint_percentages
          instance_warmup              = preferences.value.instance_warmup
          max_healthy_percentage       = preferences.value.max_healthy_percentage
          min_healthy_percentage       = preferences.value.min_healthy_percentage
          scale_in_protected_instances = preferences.value.scale_in_protected_instances
          skip_matching                = preferences.value.skip_matching
          standby_instances            = preferences.value.standby_instances

          dynamic "alarm_specification" {
            for_each = (
              preferences.value.alarm_specification == null
              ? []
              : [preferences.value.alarm_specification]
            )
            content {
              alarms = alarm_specification.value.alarms
            }
          }
        }
      }
    }
  }

  dynamic "launch_template" {
    for_each = var.instance_type == null ? [] : [1]
    content {
      id      = aws_launch_template.it.id
      version = aws_launch_template.it.latest_version
    }
  }

  dynamic "mixed_instances_policy" {
    for_each = var.instance_type == null ? [1] : []
    content {
      instances_distribution {
        on_demand_allocation_strategy            = var.mixed_instances_distribution.on_demand_allocation_strategy
        on_demand_base_capacity                  = var.mixed_instances_distribution.on_demand_base_capacity
        on_demand_percentage_above_base_capacity = var.mixed_instances_distribution.on_demand_percentage_above_base_capacity
        spot_allocation_strategy                 = var.mixed_instances_distribution.spot_allocation_strategy
        spot_instance_pools                      = var.mixed_instances_distribution.spot_instance_pools
        spot_max_price                           = var.mixed_instances_distribution.spot_max_price
      }

      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.it.id
          version            = aws_launch_template.it.latest_version
        }

        dynamic "override" {
          for_each = var.mixed_instances_overrides
          content {
            instance_type     = override.value.instance_type
            weighted_capacity = override.value.weighted_capacity

            dynamic "instance_requirements" {
              for_each = (
                override.value.instance_requirements == null
                ? []
                : [override.value.instance_requirements]
              )
              iterator = each
              content {
                accelerator_manufacturers                               = each.value.accelerator_manufacturers
                accelerator_names                                       = each.value.accelerator_names
                accelerator_types                                       = each.value.accelerator_types
                allowed_instance_types                                  = each.value.allowed_instance_types
                bare_metal                                              = each.value.bare_metal
                burstable_performance                                   = each.value.burstable_performance
                cpu_manufacturers                                       = each.value.cpu_manufacturers
                excluded_instance_types                                 = each.value.excluded_instance_types
                instance_generations                                    = each.value.instance_generations
                local_storage                                           = each.value.local_storage
                local_storage_types                                     = each.value.local_storage_types
                max_spot_price_as_percentage_of_optimal_on_demand_price = each.value.max_spot_price_as_percentage_of_optimal_on_demand_price
                on_demand_max_price_percentage_over_lowest_price        = each.value.on_demand_max_price_percentage_over_lowest_price
                require_hibernate_support                               = each.value.require_hibernate_support
                spot_max_price_percentage_over_lowest_price             = each.value.spot_max_price_percentage_over_lowest_price

                memory_mib {
                  max = each.value.memory_mib.max
                  min = each.value.memory_mib.min
                }

                dynamic "accelerator_count" {
                  for_each = each.value.accelerator_count == null ? [] : [1]
                  content {
                    max = each.value.accelerator_count.max
                    min = each.value.accelerator_count.min
                  }
                }

                dynamic "accelerator_total_memory_mib" {
                  for_each = each.value.accelerator_total_memory_mib == null ? [] : [1]
                  content {
                    max = each.value.accelerator_total_memory_mib.max
                    min = each.value.accelerator_total_memory_mib.min
                  }
                }

                dynamic "baseline_ebs_bandwidth_mbps" {
                  for_each = each.value.baseline_ebs_bandwidth_mbps == null ? [] : [1]
                  content {
                    max = each.value.baseline_ebs_bandwidth_mbps.max
                    min = each.value.baseline_ebs_bandwidth_mbps.min
                  }
                }

                dynamic "memory_gib_per_vcpu" {
                  for_each = each.value.memory_gib_per_vcpu == null ? [] : [1]
                  content {
                    max = each.value.memory_gib_per_vcpu.max
                    min = each.value.memory_gib_per_vcpu.min
                  }
                }

                dynamic "network_bandwidth_gbps" {
                  for_each = each.value.network_bandwidth_gbps == null ? [] : [1]
                  content {
                    max = each.value.network_bandwidth_gbps.max
                    min = each.value.network_bandwidth_gbps.min
                  }
                }

                dynamic "network_interface_count" {
                  for_each = each.value.network_interface_count == null ? [] : [1]
                  content {
                    max = each.value.network_interface_count.max
                    min = each.value.network_interface_count.min
                  }
                }

                dynamic "total_local_storage_gb" {
                  for_each = each.value.total_local_storage_gb == null ? [] : [1]
                  content {
                    max = each.value.total_local_storage_gb.max
                    min = each.value.total_local_storage_gb.min
                  }
                }

                dynamic "vcpu_count" {
                  for_each = each.value.vcpu_count == null ? [] : [1]
                  content {
                    max = each.value.vcpu_count.max
                    min = each.value.vcpu_count.min
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  dynamic "tag" {
    for_each = local.tags_autoscaling_group
    content {
      key   = tag.key
      value = tag.value
      # Instance tags are added in the launch template.
      propagate_at_launch = false
    }
  }

  lifecycle {
    ignore_changes = [
      desired_capacity,
    ]
  }
}
