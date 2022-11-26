#
# Cookbook:: web
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.
package 'tomcat' do
  action :install
end
execute 'download-jenkins' do
  command 'wget -O /var/lib/tomcat/webapps/jenkins.war http://mirrors.jenkins.io/war/latest/jenkins.war'
end
file '/var/lib/tomcat/webapps/jenkins.war' do
  mode '0755'
  owner 'tomcat'
  group 'tomcat'
end
service 'tomcat' do
  action [:stop, :start]
end

