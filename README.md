# Liveboard_free for NagiosXI
LiveBoard™ is a real-time alerts dashboard for Nagios XI. This dashboard will display non-OK states of nagios check results.

LiveBoard is urgency aware. Convenient, because urgent problems are always on top. You may have several LiveBoards running throughout your organisation there are separate views for each team based on authorisation.

The default installation of Nagios XI (as downloaded from nagios.com/downloads/nagios-xi) will meet the requirements needed for LiveBoard to work.

Steps to get LiveBoard to work:

Start a terminal to the Nagios XI server

Login as root (sudo may not work)

Download script start_liveboard-free.sh 
(eg. wget github.com/asamsystems/liveboard_free-for-nagiosxi/raw/master/start_liveboard-free.sh)

Run script with command: sh start_liveboard-free.sh

The script will guide you through the installation process. The script will even download the liveboard_free-for-nagiosxi docker image for you...
