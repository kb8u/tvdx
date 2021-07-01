You have installed a program to read the log files of the SDR# plugin called
FM DX RDS Data Logger.  See SDR_SHARP_README.txt for more information on
installing and configuring that plugin.

This program scans the log files of that plugin and displays the stations
dected at https://rabbitears.info/fm_all_tuners where maps are available
to show what FM transmitters were detected by all participants.  You must
email kb8u_vhf@hotmail.com with a description for the map, latitude, and
longitude so that the site will accept your data and show your location.
You will get a numeric ID back that will be used to create a map specific
to your location.

This program is normally installed to
C:\FM_SDRSHARP\report_file.exe  Also, a scheduled task has been configured so
that the program starts automatically after installation and after each computer
restart.  SDR# will not be started automatically, you'll need to do that.
If SDR# is not started, this program will do nothing.

Windows Defender may issue a security warning 'Win32/Execution.ST!ml' flagging
this program.  It is because the installer ran a program to schedule the task
so the warning may be disregarded.

If you want to stop the scheduled task, that can be accomplished graphically
through the windows task scheduler or running a command (Windows key + r):

schtasks /end /tn "FM SDRsharp reporter"

run with administrator priviliges.  To run the command as administrator, type
control-shift-return instead of just return in the run command dialog.

Similarly, to restart the scheduled task, run
schtasks /run /tn "FM SDRsharp reporter"
and if you want to delete the scheduled task, run
schtasks /delete /f /tn "FM SDRsharp reporter"
(both as administrator.)

If you have SDR# installed in a different location than normal, you will need
to take some additional steps to get this program to work.  Options must be
added to the scheduled task.  The program accepts the following options:


-d Print debugging information.
-h Print help
-i Frequency/PI code combinations to ignore like 89.9,B205,103.7,83BC
   Also reads input from file ignore_pi.txt in installation directory,
   one entry per line, like 89.9,B205
-p RDS scan file path.  Defaults to C:/SDRSharp/RDSDataLogger
   use / instead of \ in the path name.
-P RDS Ffile prefix.  Deafualts to RDSDataLogger-
-t Mandatory ID (as described above)
-T Send scan results every (this many minutes).  Default 5 minutes.  Minimum
   of 5 minutes.

In the examples below, you must use your ID instead of XXX after the -t option

Additional options can be added by running the command (as administrator):
schtasks /change /tn "FM SDRsharp reporter" /tr "'C:\FM_SDRSHARP\report_file.exe' -t XXX"
if a path has a space in it, you'll need to use triple quotes to escape it like:
schtasks /change /tn "FMDX reporter" /tr "'C:\FM_SDRSHARP\reporter_file.exe' -t XXX -p """C:\SDR Sharp\RDSDataLogger\RDSDataLogger-"""

If you want to see what the program is doing in real time, stop the scheduled
task, open a cmd window and run C:\FM_SDRSHARP\report_file.exe -d -t XXX
The -d option will print debugging information to the screen as the program
runs.
