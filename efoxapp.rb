#!/usr/bin/env ruby

# Steps to convert firefox plugin to a xulrunner app:
# 0. download http://s3.amazonaws.com/ec2-downloads/elasticfox.xpi
# 1. mkdir -p defaults/preferences
# 2. mkdir extensions
# 3. mkdir updates
# 4. create chrome/chrome.manifest
#    actually, this file should be moved from ./chrome.manifest and all instances of 'jar:chrome/' replaced with 'jar:'
# 5. create defaults/preferences/prefs.js
# 6. create ./application.ini
#    

require 'fileutils'
require 'rubygems'
require 'zip/zip'

require 'fileutils'
include FileUtils::Verbose

def web_get (uri, destination)
  uri = $1 if uri.match(/^http[s]?:\/\/(.*)/)   # strip http(s)://
  uri.match(/([^\/]+)(.*)/)                     # extract host and path from uri
  Net::HTTP.start($1) do |http|
    resp = http.get($2)
    open(destination, 'wb') do |file|
      file.write(resp.body)
    end
  end
end

def unzip_file (file, destination)
  Zip::ZipFile.open(file) do |zip_file|
    zip_file.each do |f|
      f_path=File.join(destination, f.name)
      FileUtils.mkdir_p(File.dirname(f_path))
      zip_file.extract(f, f_path) unless File.exist?(f_path)
    end
  end
end


$output_dir = "#{Dir.getwd}/efoxout"
$elasticfox_uri = 'http://s3.amazonaws.com/ec2-downloads/elasticfox.xpi'
$xulrunner = '/usr/bin/xulrunner'

rm_rf $output_dir

if not File.exists?('./elasticfox.xpi')
  web_get($elasticfox_uri,'./elasticfox.xpi')
end
unzip_file('./elasticfox.xpi',$output_dir)
cd $output_dir
mkdir 'defaults'
mkdir 'defaults/preferences'
mkdir 'extensions'
mkdir 'updates'
mv 'chrome.manifest','chrome/'
# fix chrome.manifest
File.open('chrome/chrome.manifest','r+') do |file|
  s = file.read
  s.gsub!('jar:chrome/','jar:')
  file.rewind
  file.write s
end

File.open('defaults/preferences/prefs.js','w') do |file|
file.puts <<EOS
pref("toolkit.defaultChromeURI", "chrome://ec2ui/content/ec2ui_main_window.xul");
pref("signon.rememberSignons", true);
pref("signon.expireMasterPassword", false);
pref("signon.SignonFileName", "signons.txt");
/* debugging prefs */
pref("browser.dom.window.dump.enabled", true);
pref("javascript.options.showInConsole", true);
pref("javascript.options.strict", true);
pref("nglayout.debug.disable_xul_cache", true);
pref("nglayout.debug.disable_xul_fastload", true);
EOS
end

File.open('application.ini','w') do |file|
file.puts <<EOS
[App]
Vendor=Amazon
Name=Elasticfox
Version=1.0
BuildID=20080109
Copyright=Copyright (c) 2007 Amazon
ID=elasticfox@amazon.com
[Gecko]
MinVersion=1.8
MaxVersion=1.9.0.*
EOS
end

$home_dir = ENV['HOME']

# For Ubuntu (and other Gnome desktops) create a desktop launcher
File.open("#{$home_dir}/Desktop/elasticfox.desktop",'w') do |file|
file.puts <<EOS
[Desktop Entry]
Version=1.0
Encoding=UTF-8
Name=Elasticfox
Type=Application
Terminal=false
Exec=#{$xulrunner} #{$output_dir}/application.ini
Comment=Run Elasticfox without Firefox
Icon=gnome-panel-launcher
EOS
end
