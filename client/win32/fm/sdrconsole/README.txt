You have installed a program to read the log files of the RDS decoder in
SDR Console.  This program controls the frequency in SDR Console by serial
port.  That usually requires a virtual serial port to be set in SDR Console.
The corresponding COM port is used by this program to set the frequency.
See SDR_CONSOLE_README.txt for more information.

This program reads the log file (an sqlite database) and displays the stations
dected at https://rabbitears.info/fm_all_tuners where maps are available
to show what FM transmitters were detected by all participants.  You must
email kb8u_vhf@hotmail.com with a description for the map, latitude, and
longitude so that the site will accept your data and show your location.
You will get a numeric ID back that will be used to create a map specific
to your location.

This program is normally installed to
C:\FM_SDRCONSOLE\report_sqlite.exe  Also, a scheduled task has been configured so
that the program starts automatically after installation and after each computer
restart.  SDR Console will not be started automatically, you'll need to do that.
If SDR Console is not started, this program will do nothing.

Windows Defender may issue a security warning 'Win32/Execution.ST!ml' flagging
this program.  It is because the installer ran a program to schedule the task
so the warning may be disregarded.

If you want to stop the scheduled task, that can be accomplished graphically
through the windows task scheduler or running a command (Windows key + r):

schtasks /end /tn "FM SDR Console reporter"

run with administrator priviliges.  To run the command as administrator, type
control-shift-return instead of just return in the run command dialog.

Similarly, to restart the scheduled task, run
schtasks /run /tn "FM SDR Console reporter"
and if you want to delete the scheduled task, run
schtasks /delete /f /tn "FM SDR Console reporter"
(both as administrator.)

If you have SDR Console installed in a different location than normal, you will need
to take some additional steps to get this program to work.  Options must be
added to the scheduled task.  The program accepts the following options:

-c COM port that SDR Console is on.  Defaults to COM4
-d Print debugging information.
-h Print help (you're reading it)
-p SDR Console database path.  use / instead of \ in path names.
-P SDR Console database file name.  Defaults to RDSDatabase.sqlite
-s Change frequency every this many seconds.  Default is 8 seconds
-t Mandatory ID sumber so web site can know what tuner is where.
-T send scan results every (this many seconds).  Default 300 seconds.
   Minimum of 300 seconds.
-u URL to send data to (developer may ask you to set this to help debug).

In the examples below, you must use your ID instead of XXX after the -t option

Additional options can be added by running the command (as administrator):
schtasks /change /tn "FM SDR Console reporter" /tr "'C:\FM_SDRCONSOLE\report_sqlite.exe' -t XXX"
if a path has a space in it, you'll need to use triple quotes to escape it like:
schtasks /change /tn "FMDX reporter" /tr "'C:\FM_SDRCONSOLE\reporter_file.exe' -t XXX -p """C:\SDR Console\database"""

If you want to see what the program is doing in real time, stop the scheduled
task, open a cmd window and run C:\FM_SDRCONSOLE\report_sqlite.exe -d -t XXX
The -d option will print debugging information to the screen as the program
runs.
