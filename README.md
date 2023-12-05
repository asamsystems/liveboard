# Liveboard
LiveBoard™ is a real-time alerts dashboard for Nagios XI / Thruk / Naemon. This dashboard will display non-OK states of check results.
Check out https://asamsystems.com/index.php?option=com_content&view=article&id=1

LiveBoard is urgency aware. Convenient, because urgent problems are always on top. You may have several LiveBoards running throughout your organisation there are separate views for each team based on authorisation.

The default installation of Nagios XI (as downloaded from nagios.com/downloads/nagios-xi) will meet the requirements needed for LiveBoard to work.
Steps to get LiveBoard to work:  
- Start a terminal to the Nagios/Thruk/Naemon server
- Login as root (sudo may not work)
- Download script install_liveboard.pl (eg. wget github.com/asamsystems/liveboard/raw/master/install_liveboard.pl)
- Run script with command: perl install_liveboard.pl

The script will guide you through the installation process. The script will even download the liveboard docker image for you...
