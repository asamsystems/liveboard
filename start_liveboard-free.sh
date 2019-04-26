#!/bin/bash -

XI_INC="/usr/local/nagiosxi/html/config.inc.php"
MENUFILE="/usr/local/nagiosxi/html/includes/utils-menu.inc.php"
MYCONF="/etc/my.cnf"

EDITION="liveboard_free-for-nagiosxi"
TMPCONF="/tmp/liveboard.conf"
CONF="/etc/httpd/conf.d/liveboard.conf"
XIVER="/usr/local/nagiosxi/var/xiversion"
PORT=7777


if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
echo
echo
echo
echo
echo "                LiveBoard for Nagios XI"
echo "               ========================="
echo "Starting installation of LiveBoard Free Edition for Nagios XI"
echo
echo "This script will install and take several steps to make LiveBoard work."
echo "Run this script again to uninstall/reinstall the LiveBoard container"
echo "or to select other option"
echo "LiveBoard URL: https://<nagiosxi host>/asam/liveboard"
echo
echo "-----------------------------------------------------------------------"
echo
read -p "Enter to continue or Ctrl-C to abort" X
echo
echo
echo "Checking if docker is installed: "
docker version --format '{{.Server.Version}}'
STATUS=$?
echo
if [ $STATUS -ne 0 ]; then
  echo "Cannot find the docker program.";
  echo "Do you want me to install it?"
  echo "Access to your OS packages repo (internet) will be required"
  read -p "Install (Y or n): " INST
  if [ $INST = 'Y' ]; then
    yum install -y yum-utils
    yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce
    STATUS=$?
    if [ $STATUS -ne 0 ]; then
      echo "Installing $EDITION Edition failed."
      echo "Exiting..."
      echo
      exit 1
    fi;
  else
    echo "Exiting..."
    echo
    exit 1
  fi
fi

echo "Enabling docker to start automatically"
systemctl --version > /dev/null 2>&1
STATUS=$?
if [ $STATUS -eq 0 ]; then
  systemctl enable docker > /dev/null 2>&1
  systemctl start docker > /dev/null 2>&1
  #systemctl status docker > /dev/null 2>&1
  STATUS=$?;
else
  service docker on
  service docker start > /dev/null 2>&1
  #service docker status > /dev/null 2>&1
  STATUS=$?
fi;
if [ $STATUS -eq 0 ]; then
  echo "Enabled";
else
  echo "Failed to enable docker service"
  echo
  exit 1
fi;

PID="$(docker inspect --format {{.State.Pid}} $EDITION 2>/dev/null)" #will fail if container not exist
STATUS=$?
echo
if [ $STATUS -ne 0 ]; then
  UP=$(pgrep mysql | wc -l);
  if [ $UP -eq 0 ]; then
    echo "MySQL appears to be down.";
    echo "Please start MySQL before continuing."
    echo
    exit 1
  fi
  echo "MySQL appears to be running"
  echo
  echo "About to create readonly user for nagios database."
  echo "Enter MySQL root password (or leave blank for default): "
  read -p "Password: " -s MYSQLPW
  MYSQLPW=${MYSQLPW:=nagiosxi}
  echo

  mysql -uroot -p$MYSQLPW -e "drop user 'live'@'localhost'" >/dev/null 2>&1 #suppress err msg
  mysql -uroot -p$MYSQLPW << EOF >/dev/null
    select count(*) from nagios.nagios_conninfo;
    create user 'live'@'localhost' identified by 'n@gweb';
    grant select on nagios.* to live;
    grant select on nagiosxi.* to live;
EOF
  STATUS=$?
  if [ $STATUS -ne 0 ]; then
    echo
    echo "Failed to create readonly user for nagios database"
    echo "Exiting..."
    echo
    exit 1;
  else
    echo
    echo "Created readonly user"
    echo
  fi
    echo "Creating container $EDITION Edition"
    mysqlSocket=$(dirname `grep -oiP '^socket\s*=\s*\K.+' $MYCONF`)
    mysqlSocketFile=$(basename `grep -oiP '^socket\s*=\s*\K.+' $MYCONF`)
    HTPASSWD=`grep -oiP 'htaccess_file.*\s*=\s*\K.+' $XI_INC`
    HTPASSWD=`sed -e 's/"//g'  -e "s/'//g"  -e 's/;//g' <<<  $HTPASSWD`  #rm " ' ;
    HTPASSWDPATH=$(dirname "$HTPASSWD")
    HTPASSWDFILE=$(basename "$HTPASSWD")
    XIVER=`grep -oiP '^major.+\K\d+' $XIVER`
    printf "Container ID: "
    docker run -d --restart unless-stopped \
             -v $mysqlSocket:/usr/local/bshed/mysql:ro \
             -v $HTPASSWDPATH:/usr/local/bshed/nagiosxi:ro \
             -e mysqlSocket=/usr/local/bshed/mysql/$mysqlSocketFile \
             -e HTPASSWD=/usr/local/bshed/nagiosxi/$HTPASSWDFILE \
             -e PORT=$PORT -e XIVER=$XIVER -e EDITION=$EDITION \
             --name $EDITION asamsystems/$EDITION "/usr/local/bshed/starman_start.sh"
  echo
  PID="$(docker inspect --format {{.State.Pid}} $EDITION 2>/dev/null)"
  status=$?
  if [ $status -ne 0 ]; then
    echo "Failed to (re)start $EDITION container: exit code $status"
    echo "Exiting..."
    echo
    exit $status
  else
    echo "Started Liveboard with PID $PID";
    echo
  fi;
else
  if [ $PID -le 1 ]; then
    printf "Staring container name: "
    docker start $EDITION
    echo
    status=$?
    if [ $status -ne 0 ]; then
      echo "Failed to (re)start Liveboard container: exit code $status"
      echo "Exiting..."
      echo
      exit $status
    else
      PID="$(docker inspect --format {{.State.Pid}} $EDITION 2>/dev/null)"
      echo "Started Liveboard container with PID $PID";
    fi;
  else
    echo "Liveboard container already started with pid $PID";
  fi;
fi

IP="$(docker inspect --format '{{.NetworkSettings.IPAddress}}' $EDITION 2>/dev/null)"
status=$?
if [ $status -ne 0 ]; then
  echo "Something went wrong, missing IP address"
  echo "Exiting..."
  echo
  exit $status;
fi

echo "Container IP: $IP";
echo

echo "#---
ProxyPass        /asam/liveboard http://$IP:$PORT/asam/liveboard retry=0 disablereuse=On
ProxyPassReverse /asam/liveboard http://$IP:$PORT/asam/liveboard
#---" > $TMPCONF
echo
echo
echo "File $TMPCONF has been prepared for the Apache webserver"
echo "This file needs to be added to the Apache config"
echo
echo "Pick an option and hit Enter"
echo "1) Copy file to $CONF, I will restart Apache manually"
echo "2) Copy file to $CONF & restart Apache"
echo "3) Skip, I will copy conf file & restart Apache manually"
echo "4) Skip, $CONF already exists
   with IP $IP in it"
echo "5) Add LiveBoard to the Quick View menu
   (may need repeating after a Nagios XI update)"
echo "6) Remove LiveBoard from menu"
echo "D) Stop and delete container immedialely"
echo "C) Clean all (To re-install run this script again)"
echo
read -p "Option: " opt
case $opt in
  "1") echo "Copying to $CONF "
       /bin/cp $TMPCONF $CONF
       if [ $? -ne 0 ]; then
         echo "Failed to copy. Exiting..."
         echo
         exit 1;
       fi
       ;;
  "2") echo "Copying to $CONF ..."
       /bin/cp $TMPCONF $CONF
       if [ $? -ne 0 ]; then
         echo "Failed to copy. Exiting..."
         echo
         exit 1;
       fi
       echo "Restarting Apache webserver ..."
       apachectl graceful
       if [ $? -ne 0 ]; then
         echo "Failed to restart. Exiting..."
         echo
         exit 1;
       fi
       ;;
  "3") echo
       ;;
  "4") echo
       ;;
  "5") /bin/grep liveboard $MENUFILE > /dev/null 2>&1
       STATUS=$?
       if [ $STATUS -ne 0 ]; then
         sed -i'.bak' "0,/add_menu_item(MENU_HOME, array/ {N; s/add_menu_item(MENU_HOME, array/add_menu_item(MENU_HOME, array('type' => 'link','title' => _('LiveBoard'),'id' => 'menu-home-liveboard','order' => 100.1,'opts' => array('href' => '\/asam\/liveboard\/','icon' => 'fa-heartbeat')));add_menu_item(MENU_HOME, array('type' => 'linkspacer','order' => 100.2));\n&/}" $MENUFILE;
       fi
       echo
       ;;
  "6") /bin/cp -p ${MENUFILE}.bak $MENUFILE
       echo
       ;;
  "D") printf "Stopping container "
       docker stop -t4 $EDITION
       if [ $? -ne 0 ]; then
         echo "Failed to stop container. Exiting..."
         echo
         exit 1;
       fi
       printf "Removing container "
       docker rm --force $EDITION
       if [ $? -ne 0 ]; then
         echo "Failed to remove container. Exiting..."
         echo
         exit 1;
       fi
       ;;
  "C") printf "Stopping container "
       docker stop -t4 $EDITION
       if [ $? -ne 0 ]; then
         echo "Failed to stop container. Exiting..."
         echo
         exit 1;
       fi
       printf "Removing container "
       docker rm --force $EDITION
       if [ $? -ne 0 ]; then
         echo "Failed to remove container. Exiting..."
         echo
         exit 1;
       fi
       printf "Deleting image "
       docker rmi $(docker images --filter "dangling=true" -q) 2>/dev/null
       docker rmi --force $(docker images --format "{{.ID}} {{.Repository}}"|grep liveboard|awk '{print $1;}')
       if [ $? -ne 0 ]; then
         echo "Failed to remove image. Exiting..."
         echo
         exit 1;
       fi

       ;;
    *) echo "Invalid key..."
       exit 1
       ;;
esac

echo "Done..."
echo
echo "Run this script again to select other options"
echo "LiveBoard URL: https://<nagiosxi host>/asam/liveboard"
echo
echo

