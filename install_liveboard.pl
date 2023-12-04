#!/usr/bin/env perl
#<<<
# Copyright (c), 2023 ASAM Systems Manager BV
# ver=[23338]
# Contact: devteam@asamsystems.com
#>>>
#
# script: install_liveboard.pl

use strict;
use warnings;

print "\n\n\n
======================================================================
                             LiveBoard
======================================================================
Starting installation of the LiveBoard dashboard
Liveboard works with NagiosXI, Thruk and OMD-Thruk Livestatus
This script will download the latest LiveBoard docker image
and take several steps to make LiveBoard work
Run this script again to uninstall/reinstall LiveBoard
or to select other options
LiveBoard will be added to your NagiosXI/Thruk menu


   Copyright(c) 2023 ASAMSytems.com
   Contact: devteam\@asamsystems.com
-----------------------------------------------------------------------

Enter to continue or Ctrl-C to abort: ";
<STDIN>;
print "\n";

if ($< != 0) {
  die "\nThis script must be run as root\n\n";
}
(my $inDocker=`cat /proc/1/cgroup 2>/dev/null|grep docker`)=~s/\n/ /g;
if(-e '/.dockerenv'||$inDocker){
  die "\nCannot continue in container... Exiting\n\n";
}
my $EDITION = 'liveboard';
my $localInstallFile='install_liveboard_local.pl';
my $PORT = 7777;
(my $linux_id=`cat /etc/*rel* 2>/dev/null|grep ^ID`)=~s/\n/ /g;
if($linux_id=~/centos|rhel|redhat|fedora/i){
  $linux_id='rhel';
}elsif($linux_id=~/ubuntu|debian/i){
  $linux_id='ubuntu';
}elsif($linux_id=~/alpine/i){
  $linux_id='alpine';
}else{
  die "Unknown linux distribution\nExiting...\n";
}

print "Checking if docker is installed... ";
system("docker version --format '{{.Server.Version}}'");
my $STATUS = $? >> 8;
if ($STATUS != 0) {
  print "Cannot find the docker program.\n";
  print "Do you want me to install it?\n";
  print "Access to your OS packages repo (internet) will be required\n";
  print "Install (Y or n): ";
  my $INST = <STDIN>;
  chomp($INST);
  if ($INST eq 'Y') {
    if($linux_id eq 'rhel'){
      system("yum install -y yum-utils");
      system("yum-config-manager --add-repo https://download.docker.com/linux/$linux_id/docker-ce.repo");
      system("yum install -y docker-ce");
      $STATUS = $? >> 8;
    }elsif($linux_id eq 'ubuntu'){
      die("Ubuntu installer here\n");
      system("add-apt-repository https://download.docker.com/linux/$linux_id/docker-ce.repo");
      $STATUS = $? >> 8;
    }elsif($linux_id eq 'alpine'){
      system("apk add docker");
      $STATUS = $? >> 8;
    }
    if ($STATUS != 0) {
      die ("Installing $EDITION Edition failed. Exiting...\n\n");
    }
  }else{
    die("Exiting...\n\n");
  }
}

print "Enabling docker to start automatically... ";
if($linux_id eq 'rhel'){
  system("systemctl enable docker > /dev/null 2>&1");
  system("systemctl start docker > /dev/null 2>&1");
  $STATUS = $? >> 8;
}elsif($linux_id eq 'ubuntu'){
  #ubuntu stuff her
}elsif($linux_id eq 'alpine'){
  system("rc-update add docker default > /dev/null 2>&1");
  system("service docker start > /dev/null 2>&1");
  $STATUS = $? >> 8;  
}
if ($STATUS == 0) {
  print "Enabled\n";
} else {
  die "Failed\n\n";
}

my $PID = `docker inspect --format {{.State.Pid}} $EDITION 2>/dev/null`; # will fail if container not exist
$STATUS = $? >> 8;
chomp($PID);
print "Container $EDITION exists... ";
if ($STATUS == 0) {
  print "Yes\n";
  if($PID==0){
    print "Container $EDITION appears to be down\n";
    print "Starting container ";
    system("docker start $EDITION");
    $STATUS = $? >> 8;
    if ($STATUS != 0) {
      die "Failed to (re)start $EDITION container\nExiting...\n\n";
    } else {
      $PID = `docker inspect --format {{.State.Pid}} $EDITION 2>/dev/null`;
      chomp($PID);
      print "Started $EDITION container with PID $PID\n";
    }
  } else {
    print "Container $EDITION already started with pid $PID\n";
  }
}else{
  print "No\n";
  print "Creating container\n";
  my $dockerCommand ="docker run -d --restart unless-stopped " .
                     "-p 0.0.0.0:$PORT:$PORT/tcp " .
                     "--hostname $EDITION " .
                     "--name $EDITION asamsystems/$EDITION /start.sh";

  my $containerID = `$dockerCommand`||'';
  $STATUS = $? >> 8;
  die "Failed to find/download $EDITION image. Exiting...\n\n" if $STATUS;
  chomp($containerID);
  print "Container ID: $containerID\n";
  die "\nFailed to start $EDITION container\nExiting...\n\n" if($STATUS!=0||!$containerID);
  print "Started $EDITION container\n";
}
my $liveboard_ip = `docker inspect --format '{{.NetworkSettings.IPAddress}}' $EDITION 2>/dev/null`;
$STATUS = $? >> 8;
chomp($liveboard_ip);
die "Something went wrong, missing container IP\nExiting...\n\n" if($STATUS!=0);
print "Container IP: $liveboard_ip\n\n";

print "Writing ./$localInstallFile
Make sure container can connect to NagiosXI/Thruk host port 6557
Run this file from /tmp on the machine where NagiosXI/Thruk is installed
Run command: perl ./$localInstallFile\n\n";
open(my $fh,'>',"./$localInstallFile")||die "$!\n";
print $fh q[#!/usr/bin/env perl
#<<<
# Copyright (c), 2023 ASAM Systems Manager BV
# ver=[23338]
# Contact: devteam@asamsystems.com
#>>>
#
# script: install_liveboard_local.pl

use strict;
use warnings;

if ($< != 0) {
  die "\nThis script must be run as root\n\n";
}
my $liveboard_ip='].$liveboard_ip.q[';
my $MenuItemName ='LiveBoard';
my $TMPCONF = "./liveboard.conf";
my $TMPMENUFILE="./menu_local.conf";
my $PORT =].$PORT.q[;
my $LIVE_PORT=6557;
(my $linux_id=`cat /etc/*rel* 2>/dev/null|grep ^ID`)=~s/\n/ /g;
if($linux_id=~/centos|rhel|redhat|fedora/i){
  $linux_id='rhel';
}elsif($linux_id=~/ubuntu|debian/i){
  $linux_id='ubuntu';
}else{
  die "Unknown linux distribution\nExiting...\n";
}

print "Verifying version install type... ";
system("omd version 2>/dev/null");
my $STATUS = $? >> 8;
my @sites;
my $siteName='thruk';
my $installType;
if($STATUS==0){
  @sites=`omd sites -b`;
  die "At least 1 OMD site must exist\n" unless scalar @sites;
  print "Found OMD-Thruk\n";
  $installType='OMD';
  if(scalar(@sites)==1){
    $siteName=$sites[0];
    chomp $siteName;
  }else{
    print "Following sites are available:\n";
    print $_ for @sites;
    print "Enter site for which to install $MenuItemName: ";
    $siteName=<STDIN>;
    chomp $siteName;
    die "Not found, exiting...\n\n" if(!grep(/^$siteName$/,@sites));
  }
}elsif(-e '/etc/thruk/thruk.conf'){
  print "Found Thruk\n";
  $installType='THRUK';
  #rpm install does not create thruk user
}elsif(-e '/usr/local/nagiosxi/html/includes/utils-menu.inc.php'){
  print "Found Nagiosxi\n";
  $installType='NAGIOSXI';
  $siteName='nagiosxi';
}else{
  print "Cannot find NagiosXI/Thruk.\n";
  print "Prepare files for NagiosXI, Thruk or OMD install?\n";
  print "Enter NAGIOSXI or THRUK or OMD : ";
  $installType=<STDIN>;
  chomp $installType;
  die "Option not found. Exiting...\n" unless $installType=~/^NAGIOSXI|THRUK|OMD$/;
}
my $owner=$siteName;
my $OMD_SITE='thruk';
my $OMD_SITE_ENV='thruk';
my $OMD_ROOT='/';
my $OMD_ROOT_ENV='/usr';
my $MENUFILE ='etc/thruk/menu_local.conf';
my $webConf='etc/httpd/conf.d/liveboard.conf';
my $webserverRestart='apachectl -t && apachectl graceful';
my $DocumentRoot='/var/www/html';
if($installType eq 'OMD'){
  $OMD_ROOT="/omd/sites/$siteName";
  $OMD_ROOT_ENV='$ENV{OMD_ROOT}';
  $OMD_SITE='${OMD_SITE}';
  $OMD_SITE_ENV='$ENV{OMD_SITE}';
  $webConf='etc/apache/conf.d/liveboard.conf';
  $MENUFILE='etc/thruk/menu_local.conf';
  $LIVE_PORT='$ENV{CONFIG_LIVESTATUS_TCP_PORT}';
  $webserverRestart="omd restart $siteName apache";
  $DocumentRoot='${OMD_ROOT}/var/www';
}elsif($installType eq 'THRUK'){
  $owner='root' unless -e "/home/$siteName";
  if($linux_id eq 'rhel'){
    #defaults to rhel
    #$webConf='etc/httpd/conf.d/liveboard.conf';

  }elsif($linux_id eq 'ubuntu'){
    die "need to set ubuntu/debian paths\n";
  }elsif($linux_id eq 'suse'){
    die "need to set suse/sles paths\n";
  }
}elsif($installType eq 'NAGIOSXI'){
  $owner='nagios';
  $OMD_SITE='nagiosxi';
  $MENUFILE ='usr/local/nagiosxi/html/includes/utils-menu.inc.php';
  $DocumentRoot='/usr/local/nagiosxi/html';
  
  #check mysql and create user 'live'
  my $UP = `pgrep mysql | wc -l`;
  chomp($UP);
  if ($UP == 0) {
    die "MySQL appears to be down.\nPlease start MySQL before continuing.\n\n";
  }
  print "MySQL appears to be running\n";
  print "Creating readonly user for nagios database.\n";
  print "Enter MySQL root password (or leave blank for default): ";
  my $MYSQLPW = <STDIN>;
  chomp($MYSQLPW);
  $MYSQLPW = $MYSQLPW || "nagiosxi";

  my $mysqlCommand = q[drop user 'live'@'localhost'];
  system("mysql -uroot -p$MYSQLPW mysql -e \"$mysqlCommand\" 2>/dev/null");
  $mysqlCommand = q[drop user 'live'@'%';];
  system("mysql -uroot -p$MYSQLPW mysql -e \"$mysqlCommand\" 2>/dev/null");
  $mysqlCommand = q[create user 'live'@'%' identified by 'n@gweb';
    grant select on nagios.* to 'live'@'%';
    grant select on nagiosxi.* to 'live'@'%';
    flush privileges;
    ];
  system("mysql -uroot -p$MYSQLPW -e \"$mysqlCommand\" 2>/dev/null");
  $STATUS = $? >> 8;
  if ($STATUS != 0) {
    die "\nFailed to create readonly user for nagios database. Exiting...\n\n";
  } else {
    print "\nCreated readonly user\n\n";
  }
}else{
  die "Cannot find installtype\n\n";
}

open(my $fh, '>', "$TMPCONF.$installType")||die "$!\nExiting...\n\n";
print $fh "# Use this file if you have $installType installed
# This file has been prepared for the Apache webserver
# Copy this file to: $OMD_ROOT/$webConf
# restart (local)webserver
#---
ProxyPass        /$OMD_SITE/liveboard http://$liveboard_ip:$PORT/liveboard retry=0 disablereuse=On
ProxyPassReverse /$OMD_SITE/liveboard http://$liveboard_ip:$PORT/liveboard
#---

Alias /$siteName/asam $DocumentRoot/asam
<Directory '$DocumentRoot/asam/check'>
    SetHandler cgi-script
    Options ExecCGI
    #AddHandler cgi-script .sh
</Directory>
\n";
close $fh;
print "Written $TMPCONF.$installType\n";


if($installType eq 'NAGIOSXI'){
  open($fh, '>', "$TMPMENUFILE.$installType")||die "$!\nExiting...\n\n";
  print $fh "# Use this file if you have $installType installed
# This file will be appended to $MenuItemName menu file
# Copy this file to: $OMD_ROOT/$MENUFILE\n";

  print $fh q[
$h=array(remote_user=>get_user_attr($user_id,"username"),
  dbname=>'nagios',
  dbuser=>'live',
  dbpwd=>'n@gweb',
  table_prefix=>'nagios_',
  omd_site=>'nagiosxi',
  port=>3306,  //socket path deprecated
  isAdmin=>is_admin()||is_authorized_for_all_objects(),
  host=>rtrim(`hostname -f`)  //rm \n
);
$h=base64_encode(json_encode($h));
$chars = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
for ($i = 0; $i < 14; $i++) {
  $index = rand(0,strlen($chars)-1);
  $h = $chars[$index].$h;
}
add_menu_item(MENU_HOME, array(
  'type' => 'link',
  'title' => _('LiveBoard'),
  'id' => 'menu-home-liveboard',
  'order' => 100.1,
  'opts' => array('href' => get_base_url()."liveboard/$h",
    'icon' => 'fa-heartbeat',
    'target' => '_parent'
  )
));
add_menu_item(MENU_HOME, array(
  'type' => 'linkspacer',
  'order' => 100.2
));];
  close $fh;
}else{
open($fh, '>', "$TMPMENUFILE.$installType")||die "$!\nExiting...\n\n";
print $fh "# Use this file if you have $installType installed
# This file will add $MenuItemName to your Thruk menu
# Copy this file to: $OMD_ROOT/$MENUFILE
# Note: Comment 'do' line if menu_local.conf ALREADY exists
# do \$ENV{OMD_ROOT}/share/thruk/menu.conf\n";

if(! -e "$OMD_ROOT/$MENUFILE"){
  print $fh qq(do "$OMD_ROOT_ENV/share/thruk/menu.conf";);
}
print $fh q[
my $isAdmin=$c->check_user_roles('authorized_for_admin')||
          $c->check_user_roles('authorized_for_all_hosts')&&
          $c->check_user_roles('authorized_for_all_services')||
          0;
my $host=`hostname -f`;
chomp $host;
my %h=(remote_user=>$c->user->get('username'),
      port=>].$LIVE_PORT.q[,  #livestatus port for this host/site
      isAdmin=>$isAdmin,
      host=>"$host",          #this hostname/ip as can be found by liveboard
      omd_site=>"].$OMD_SITE_ENV.q["
);
my $h=Cpanel::JSON::XS::encode_json(\%h);
$h=MIME::Base64::encode_base64($h);
my @chars=('a'..'z','A'..'Z','0'..'9');
for(1..14){
  $h=$chars[rand @chars].$h;
}
insert_item('General', { 'href' => '/'."].$OMD_SITE_ENV.q[".'/liveboard/'.$h, 'name' => '].$MenuItemName.q[', target => '_parent' });];
close $fh;
}

print "Written $TMPMENUFILE.$installType\n\n";

mkdir('asam')||$!{EEXIST}||die("$!\n");
mkdir('asam/check')||$!{EEXIST}||die("$!\n");
mkdir('asam/prefdir')||$!{EEXIST}||die("$!\n");
open($fh,'>','asam/index.html');close $fh;
open($fh,'>','asam/check/index.html');close $fh;
open($fh,'>','asam/prefdir/index.html');close $fh;
open($fh,'>','asam/check/pref.sh')||die "$!\n";
print $fh q[#!/bin/sh
#<<<
# Copyright (c), 2023 ASAM Systems Manager BV
# ver=[23338]
# Contact: devteam@asamsystems.com
#>>>

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\x}"; }
echo -e "Content-type: text/plain\n";
y=$(urldecode "$QUERY_STRING")
a=`echo -n $y|cut -d'=' -f1`    # split '=', field 1
b=`echo -n $y|cut -d'=' -f2`
if [ $a == 'read' ]; then
  cat ../prefdir/$b
  exit 0
fi
echo $b > ../prefdir/$a
STATUS=$?
if [ $STATUS -ne 0 ]; then
  echo -n "Failed to write, exit: $STATUS"
  exit 1
fi
echo -n 'gelukt'
exit 0
];
close $fh;

print "Pick an option and hit Enter
1) Prepare webserver $OMD_ROOT/$webConf, restart manually
2) Prepare webserver & restart
3) Add menu $MenuItemName to section General
4) Remove $MenuItemName from menu

Option: ";
my $opt = <STDIN>;
chomp($opt);

if($opt eq '1') {
  print "Copying to $OMD_ROOT/$webConf\n";
  system("/bin/cp $TMPCONF.$installType $OMD_ROOT/$webConf && \
          chown $owner:$owner $OMD_ROOT/$webConf");
  $STATUS = $? >> 8;
  die "Failed to copy. Exiting...\n\n" if ($STATUS!=0);
}elsif ($opt eq '2') {
  print "Copying to $OMD_ROOT/$webConf ...\n";
  system("/bin/cp $TMPCONF.$installType $OMD_ROOT/$webConf && \
          chown $owner:$owner $OMD_ROOT/$webConf");
  $STATUS = $? >> 8;
  die "Failed to copy. Exiting...\n\n" if ($STATUS!=0);
  print "Restarting webserver ... ";
  system($webserverRestart);
  $STATUS = $? >> 8;
  die "Failed to restart. Exiting...\n\n" if ($STATUS!=0);
  print "Started\n";
}elsif ($opt eq '3') {
  if($installType eq 'NAGIOSXI'){
    system("grep -i liveboard $OMD_ROOT/$MENUFILE > /dev/null 2>&1");
    $STATUS = $? >> 8;
    if($STATUS==0){
      print "\nSkipping, 'liveboard' already exists in $OMD_ROOT/$MENUFILE\n";
    }else{  #exists but liveboard not found
      system("/bin/cp -p $OMD_ROOT/$MENUFILE $OMD_ROOT/$MENUFILE.bak && \
             chown $owner:$owner $OMD_ROOT/$MENUFILE.bak");
      $STATUS = $? >> 8;
      die "Failed to backup $OMD_ROOT/$MENUFILE\nExiting...\n\n" if($STATUS!=0);
      open($fh, '<', "$OMD_ROOT/$MENUFILE");
      my @data = <$fh>;
      close $fh;

      open($fh,'<',"$TMPMENUFILE.$installType");
      local $/;
      my $data2 = <$fh>;
      close $fh;

      my $cnt=-1;
      for (@data){
        $cnt++;
        next unless $_=~/\/\/ Quick View$/;
        $data[$cnt]="  // Quick View\n$data2\n";
        last;
      }
      open($fh, '>', "$OMD_ROOT/$MENUFILE");
      print $fh "@data\n";
      close $fh;
    }
  }else{
  if(! -e "$OMD_ROOT/$MENUFILE"){
    system("/bin/cp -p $TMPMENUFILE.$installType $OMD_ROOT/$MENUFILE && \
           chown $owner:$owner $OMD_ROOT/$MENUFILE");
  }else{
    system("grep -i liveboard $OMD_ROOT/$MENUFILE > /dev/null 2>&1");
    $STATUS = $? >> 8;
    if($STATUS==0){
      print "\nSkipping, 'liveboard' already exists in $OMD_ROOT/$MENUFILE\n";
    }else{  #exists but liveboard not found
      system("/bin/cp -p $OMD_ROOT/$MENUFILE $OMD_ROOT/$MENUFILE.bak && \
             chown $owner:$owner $OMD_ROOT/$MENUFILE.bak");
      $STATUS = $? >> 8;
      die "Failed to backup $OMD_ROOT/$MENUFILE\nExiting...\n\n" if($STATUS!=0);
      open($fh, '<', "$TMPMENUFILE.$installType");
      $/ = undef;
      my $data = <$fh>;
      close $fh;
      open($fh,'>>',"$OMD_ROOT/$MENUFILE")||die "$!\nExiting...\n\n";
      print $fh $data;
      close $fh;
    }
  }
  }
  # user root is not aware of '$OMD_ROOT'
  $DocumentRoot="$OMD_ROOT/var/www" if $DocumentRoot=~/OMD_ROOT/;
  system("/bin/cp -r asam $DocumentRoot && \
        chown -R $owner:$owner $DocumentRoot/asam && \
        chmod -R 755 $DocumentRoot/asam/check && \
        chmod -R 777 $DocumentRoot/asam/prefdir");
}elsif ($opt eq '4'){
  system("/bin/cp -p $OMD_ROOT/$MENUFILE.bak $OMD_ROOT/$MENUFILE");
}else{
  die "Option not found. Exiting...\n\n";
}
print "Done...\n\n";
print "Run this script again to select other options\n";
print "Login and click on menu-item $MenuItemName to view\n";
print "\n\n";
];
