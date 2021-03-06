#
# Copyright (C) 2013 eNovance SAS <licensing@enovance.com>
#
# Author: Emilien Macchi <emilien.macchi@enovance.com>
#         Francois Charlier <francois.charlier@enovance.com>
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.
#
# Unit tests for nova::cells class
#

require 'spec_helper'

describe 'nova::cells' do

  let :pre_condition do
    "include nova"
  end

  let :default_params do
    {:enabled                       => true,
     :bandwidth_update_interval     => '600',
     :call_timeout                  => '60',
     :capabilities                  => ['hypervisor=xenserver;kvm','os=linux;windows'],
     :db_check_interval             => '60',
     :driver                        => 'nova.cells.rpc_driver.CellsRPCDriver',
     :instance_updated_at_threshold => '3600',
     :instance_update_num_instances => '1',
     :max_hop_count                 => '10',
     :mute_child_interval           => '300',
     :mute_weight_multiplier        => '-10.0',
     :mute_weight_value             => '1000.0',
     :ram_weight_multiplier         => '10.0',
     :reserve_percent               => '10.0',
     :rpc_driver_queue_base         => 'cells.intercell',
     :scheduler_filter_classes      => 'nova.cells.filters.all_filters',
     :scheduler                     => 'nova.cells.scheduler.CellsScheduler',
     :scheduler_retries             => '10',
     :scheduler_retry_delay         => '2',
     :scheduler_weight_classes      => 'nova.cells.weights.all_weighers',
     :weight_offset                 => '1.0',
     :weight_scale                  => '1.0'}
  end

  shared_examples_for 'nova-cells' do

    it { is_expected.to contain_class('nova::params') }

    it 'installs nova-cells package' do
      is_expected.to contain_package('nova-cells').with(
        :ensure => 'present',
        :name   => platform_params[:cells_package_name],
        :tag    => ['openstack', 'nova-package']
      )
    end

    it 'configures nova-cells service' do
      is_expected.to contain_service('nova-cells').with(
        :ensure     => 'running',
        :name       => platform_params[:cells_service_name],
        :tag        => 'nova-service'
      )
    end

    it 'configures cell' do
      is_expected.to contain_nova_config('cells/bandwidth_update_interval').with(:value => '600')
      is_expected.to contain_nova_config('cells/call_timeout').with(:value => '60')
      is_expected.to contain_nova_config('cells/capabilities').with(:value => 'hypervisor=xenserver;kvm,os=linux;windows')
      is_expected.to contain_nova_config('cells/db_check_interval').with(:value => '60')
      is_expected.to contain_nova_config('cells/driver').with(:value => 'nova.cells.rpc_driver.CellsRPCDriver')
      is_expected.to contain_nova_config('cells/instance_updated_at_threshold').with(:value => '3600')
      is_expected.to contain_nova_config('cells/instance_update_num_instances').with(:value => '1')
      is_expected.to contain_nova_config('cells/max_hop_count').with(:value => '10')
      is_expected.to contain_nova_config('cells/mute_child_interval').with(:value => '300')
      is_expected.to contain_nova_config('cells/mute_weight_multiplier').with(:value => '-10.0')
      is_expected.to contain_nova_config('cells/mute_weight_value').with(:value => '1000.0')
      is_expected.to contain_nova_config('cells/ram_weight_multiplier').with(:value => '10.0')
      is_expected.to contain_nova_config('cells/reserve_percent').with(:value => '10.0')
      is_expected.to contain_nova_config('cells/rpc_driver_queue_base').with(:value => 'cells.intercell')
      is_expected.to contain_nova_config('cells/scheduler_filter_classes').with(:value => 'nova.cells.filters.all_filters')
      is_expected.to contain_nova_config('cells/scheduler_retries').with(:value => '10')
      is_expected.to contain_nova_config('cells/scheduler_retry_delay').with(:value => '2')
      is_expected.to contain_nova_config('cells/scheduler_weight_classes').with(:value => 'nova.cells.weights.all_weighers')
      is_expected.to contain_nova_config('cells/scheduler').with(:value => 'nova.cells.scheduler.CellsScheduler')
    end
  end

  shared_examples_for 'a parent cell' do
    let :params do
      { :enabled   => true,
        :cell_type => 'parent',
        :cell_name => 'mommy' }
    end
    let :expected_params do
      default_params.merge(params)
    end
    it { is_expected.to contain_nova_config('cells/name').with_value(expected_params[:cell_name]) }
    it { is_expected.to contain_nova_config('DEFAULT/compute_api_class').with_value('nova.compute.cells_api.ComputeCellsAPI')}
    it { is_expected.to contain_nova_config('cells/cell_type').with_value('api')}
    it_configures 'nova-cells'
  end

  shared_examples_for 'a parent cell with manage_service as false' do
    let :params do
      { :enabled   => true,
        :manage_service => false,
        :cell_type => 'parent',
        :cell_name => 'mommy' }
    end
    let :expected_params do
      default_params.merge(params)
    end
    it { is_expected.to contain_service(platform_params[:cells_service_name]).without_ensure }
  end

  shared_examples_for 'a child cell' do
    let :params do
      { :enabled   => true,
        :cell_type => 'child',
        :cell_name => 'henry' }
    end
    let :expected_params do
      default_params.merge(params)
    end
    it { is_expected.to contain_nova_config('cells/name').with_value(expected_params[:cell_name]) }
    it { is_expected.to contain_nova_config('DEFAULT/quota_driver').with_value('nova.quota.NoopQuotaDriver')}
    it { is_expected.to contain_nova_config('cells/cell_type').with_value('compute')}
    it_configures 'nova-cells'
  end

  on_supported_os({
    :supported_os => OSDefaults.get_supported_os
  }).each do |os,facts|
    context "on #{os}" do
      let (:facts) do
        facts.merge!(OSDefaults.get_facts())
      end

      case facts[:osfamily]
      when 'Debian'
        let (:platform_params) do
          {
              :cells_package_name => 'nova-cells',
              :cells_service_name => 'nova-cells'
          }
        end
        it_configures 'a parent cell with manage_service as false'
      when 'RedHat'
        let (:platform_params) do
          {
              :cells_package_name => 'openstack-nova-cells',
              :cells_service_name => 'openstack-nova-cells'
          }
        end
      end

      it_configures 'a parent cell'
      it_configures 'a child cell'
    end
  end

end
