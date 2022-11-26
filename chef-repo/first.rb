file "test.txt" do 
  content 'this is test content'
end
package 'httpd' do
  action [:install, :upgrade]
end
service 'httpd' do
  action [:enable, :start]
end
