#
# Author:: Christian Trabold <christian.trabold@dkd.de>
# Author:: Fletcher Nichol <fnichol@nichol.ca>
# Cookbook Name:: redis
# Recipe:: source
#
# Copyright 2011, dkd Internet Service GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

cache_dir       = Chef::Config[:file_cache_path]
install_prefix  = node['redis']['source']['prefix']
tar_url         = node['redis']['source']['tar_url']
tar_checksum    = node['redis']['source']['tar_checksum']
tar_file        = "redis-#{node['redis']['source']['version']}.tar.gz"
tar_dir         = tar_file.sub(/\.tar\.gz$/, '')
port            = node['redis']['port']
redis_user      = node['redis']['source']['user']
redis_group     = node['redis']['source']['group']

Array(node['redis']['source']['pkgs']).each { |pkg| package pkg }

current_version = shell_out("redis-server --version|grep -o -E v=[0-9]+.[0-9]+.[0-9]+").stdout.slice(2..-1)
unless current_version == node['redis']['source']['version']
  execute "Remove old redis-server #{node['redis']['source']['version']}" do
    command   "rm -rf #{install_prefix}/bin/redis-server"
  end
end

remote_file "#{cache_dir}/#{tar_file}" do
  source    tar_url
  checksum  tar_checksum
  mode      "0644"
end

execute "Extract #{tar_file}" do
  cwd       cache_dir
  command   <<-COMMAND
    rm -rf #{tar_dir} && \
    mkdir #{tar_dir} && \
    tar zxf #{tar_file} -C #{tar_dir} --strip-components 1
  COMMAND

  creates   "#{cache_dir}/#{tar_dir}/utils/redis_init_script"
end

execute "Build #{tar_dir.split('/').last}" do
  cwd       "#{cache_dir}/#{tar_dir}"
  command   %{make prefix=#{install_prefix} install}

  creates   "#{install_prefix}/bin/redis-server"
end

group redis_group

user redis_user do
  gid redis_group
  home    "/var/lib/redis"
  system  true
end

%w{/var/run/redis.pid /var/log/redis /var/lib/redis}.each do |dir|
  directory dir do
    owner       redis_user
    group       redis_group
    mode        "0750"
    recursive   true
  end
end

if node['redis']['source']['create_service']

  template "/etc/init.d/redis" do
    source  "redis_init_script.erb"
    owner   "root"
    group   "root"
    mode    "0755"
  end

  file "/etc/init.d/redis" do
    owner   "root"
    group   "root"
    mode    "0755"
  end

  directory "/etc/redis" do
    owner   "root"
    group   "root"
    mode    "0755"
  end

  template "/etc/security/limits.d/redis.conf" do
    source  "redis.conf.limits.erb"
    owner   "root"
    group   "root"
    mode    "0644"
  end

  template "/etc/redis/redis.conf" do
    source  "redis.conf.erb"
    owner   "root"
    group   "root"
    mode    "0644"
  end

end
