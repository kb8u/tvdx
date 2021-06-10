You have installed a program to read the log files of the SDR# plugin called
FM DX RDS Data Logger.  See SDR_SHARP_README.txt for more information on
installing and configuring that plugin.

This program scans the log files of that plugin and displays the stations
dected at https://rabbitears.info/fm_all_tuners where maps are available
to show what FM transmitters were detected by all participants.  You must
email webmaster@rabbitears.info with a description for the map, latitude, and
longitude so that the site will accept your data and show your location.
You will get a numeric ID back that will be used to create a map specific
to your location.

This program is normally installed to
c:\FMDX\fm_dx_reporter.exe  Also, a scheduled task has been configured so that
the program starts automatically after installation and after each computer
restart.  SDR# will not be started automatically, you'll need to do that.
If SDR# is not started, this program will do nothing.

Windows Defender may issue a security warning 'Win32/Execution.ST!ml' flagging
this program.  It is because the installer ran a program to schedule the task
so the warning may be disregarded.

If you want to stop the scheduled task, that can be accomplished graphically
through the windows task scheduler or running a command (Windows key + r):

schtasks /end /tn "FMDX reporter"

run with administrator priviliges.  To run the command as administrator, type
control-shift-return instead of just return in the run command dialog.

Similarly, to restart the scheduled task, run
schtasks /run /tn "FMDX reporter"
and if you want to delete the scheduled task, run
schtasks /delete /f /tn "FMDX reporter"
(both as administrator.)

If you have SDR# installed in a different location than normal, you will need
to take some additional steps to get this program to work.  Options must be
added to the scheduled task.  The program accepts the following options:


-d Print debugging information.
-h Print help
-p RDS scan file path.  Defaults to C:/SDRSharp/RDSDataLogger
   use / instead of \ in the path name.
-P RDS Ffile prefix.  Deafualts to RDSDataLogger-
-t Mandatory ID (as described above)
-T Send scan results every (this many minutes).  Default 5 minutes.  Minimum
   of 5 minutes.

In the examples below, you must use your ID instead of XXX after the -t option

Additional options can be added by running the command (as administrator):
schtasks /change /tn "FMDX reporter" /tr "'C:\fmdx\fm_dx_reporter.exe' -t XXX"
if a path has a space in it, you'll need to use triple quotes to escape it like:
schtasks /change /tn "FMDX reporter" /tr "'C:\fmdx\fm_dx_reporter.exe' -t XXX -p """c:\SDR Sharp\RDSDataLogger\RDSDataLogger-"""

If you want to see what the program is doing in real time, stop the scheduled
task, open a cmd window and run C:\fmdx\fm_dx_reporter.exe -d -t XXX
The -d option will print debugging information to the screen as the program
runs.
