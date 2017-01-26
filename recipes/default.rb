#
# Cookbook Name:: opendj
# Recipe:: default
#
# Copyright 2016, SourceFuse Technologies Pvt. Ltd.
#
# All rights reserved - Do Not Redistribute
#

isopendj = true

if File.exist?('/opt/opendj/bin/start-ds')
  isopendj = false
end

remote_file Chef::Config['file_cache_path'] + "/OpenDJ-2.6.0.zip"do
  source node['opendj']['zip_url']
#  checksum '702195506cf0409af75b6cc4e409f7da'
  mode '0755'
  action :create
  only_if { isopendj == true }
end

group node['opendj']['group'] do
  action :create
end

user node['opendj']['user'] do
  gid 'opendj'
  shell '/bin/bash'
  home '/home/opendj'
  system true
  action :create
end

src_filename = "OpenDJ-2.6.0.zip?dl=0"
src_filepath = "#{Chef::Config['file_cache_path']}/#{src_filename}"

execute 'extract opendj' do
	command <<-EOF
      set -e
      sudo mkdir -p /data/backup/ldap
      sudo chown -R opendj:opendj /data/backup/ldap
      cd /opt
      sudo wget "https://www.dropbox.com/s/4vwh8pfrvnia9ez/OpenDJ-2.6.0.zip?dl=0"
      sudo unzip #{src_filename}
      EOF
  only_if { isopendj == true }
end

directory node['opendj']['path'] do
  owner node['opendj']['user']
  group node['opendj']['group']
  recursive true
  mode "0755"
end

template "/opt/opendj/opendj.env" do
  source "opendj.env.erb"
  mode "0644"
end

execute 'set password' do
  command <<-EOF
  opendj_password=$(date +%s | sha256sum | base64 | head -c 15 ; echo)
  echo $opendj_password > '/root/.opendj_password'
  EOF
  only_if { isopendj == true }
end

execute 'setup opendj' do
  cwd node['opendj']['path']
  command <<-EOF
  set -e
  hostname=$(hostname -f)
  sudo chown -R opendj:opendj /opt/opendj
  cd /opt/opendj
  source /opt/opendj/opendj.env
  chmod 755 -R /opt/opendj/
  ./setup --cli --baseDN #{node['opendj']['baseDN']} --addBaseEntry --ldapPort #{node['opendj']['ldapPort']} --adminConnectorPort #{node['opendj']['adminConnectorPort']} --rootUserDN #{node['opendj']['rootUserDN']} --rootUserPassword $opendj_password --enableStartTLS --ldapsPort #{node['opendj']['ldapsPort']} --generateSelfSignedCertificate --hostName $hostname --no-prompt --noPropertiesFile --acceptLicense
  sudo chown -R opendj:opendj /opt/opendj/
  chmod 755 -R /opt/opendj/
  cd /opt/opendj/bin
  sudo ./create-rc-script -u opendj -j /usr/lib/jvm/jre -f /etc/init.d/opendj
  sudo chmod 755 /etc/init.d/opendj
  ./stop-ds
  EOF
  only_if { isopendj == true }
end

template "/etc/init.d/opendj" do
  source "opendj.erb"
  mode "0755"
end

service "opendj" do
  service_name 'opendj'
  supports :restart => true, :status => true, :reload => true
  action [:enable, :start]
end
