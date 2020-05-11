You have installed a program to continuously scan all channels on your
SiliconDust HDHomerun device on "/tuner0/".  The results are sent to
https://rabbitears.info/all_tuners where maps are available to show what
TV transmitters were detected by all participants.  You must email
webmaster@rabbitears.info with your tuner ID, a description for the map, and
latitude and longitude so that the site will accept your data and show your
location.

The program that does the scanning is normally installed to
c:\TVDX\scan_tuner.exe  Also, a scheduled task has been configured so that
the program starts automatically after installation and after each computer
restart.

If you want to use /tuner0/ for other purposes, you will need to stop the
scheduled task.  That can be accomplished graphically through the windows task
scheduler or running a command (Windows key + r):

schtasks /end /tn "TVDX scan"

run with administrator priviliges.  To run the command as administrator, type
control-shift-return instead of just return in the run command dialog.  Note
that it may take a minute or two for the tuner to actually become available
after the program is stopped.  You can power-cycle the tuner if you don't want
to wait.

Similarly, to restart the scheduled task, run schtasks /run /tn "TVDX scan"
and if you want to delete the scheduled task, run
schtasks /delete /f /tn "TVDX scan"
(both as administrator.)

If you have more than one HDHomerun device on your network, want to use a tuner
other than /tuner0/ or have hdhomerun_config.exe installed in a different
location than normal, you will need to take some additional steps to get this
program to work.  Options must be added to the scheduled task.  The program
accepts the following options:

-p Path to hdhomerun_config.exe (used to scan the tuner).  It is normally
   already installed from the CD that came with your tuner.
   Defaults to C:\Progra~1\Silicondust\HDHomeRun\hdhomerun_config.exe
-t Which tuner to use (applicable only to dual-tuner models).
   Defaults to /tuner0/
-x Tuner ID.  Only needed if you have more than one HDHomeRun on your network.
   Defaults to FFFFFFFF

Additional options can be added by running the command (as administrator):
schtasks /change /tn "TVDX scan" /tr "C:\tvdx\scan_tuner.exe -t /tuner1/"
if a path has a space in it, you'll need to use triple quotes to escape it like:
schtasks /change /tn "TVDX scan" /tr "C:\tvdx\scan_tuner.exe -p """c:\program files\silicondust\hdhomerun\hdhomerun_config.exe"""

If you want to see what the program is doing in real time, stop the scheduled
task, open a cmd window and run C:\tvdx\scan_tuner.exe -d
The -d option will print debugging information to the screen as the program
runs.