Before running fm_dx_reporter.exe, You will need to install, configure and
run SDR# and the RDS logger plugin 'FM DX RDS Data Logger' available from
https://www.apritch.co.uk/sdrsharp_plugins.htm

Install the latest plugin "Beta 19" or later by ownloading the file and
extracting it to your SDRSharp directory.  Follow the
installation instructions in RDSDataLoggerReadMe1st.txt  The plugins.xml
file you need to edit (with notepad or some other editor) is also in your
SDRSharp directory.

After you restart SDRSharp, you can then select the RDS Data Logger from the
menu.  You will need to manually configure and start the plugin from the GUI
each time you open SDRSharp.  Complete the following steps in the RDS Data
Logger dock in SDRSharp to start scanning.

Click the red 'ON' button.  It will turn gray and change to 'OFF'.
Click the '200 KHz' check box.
Click the 'Log' check box
Change 'Scan From (Hz)' to 88100000
Change 'Scan To (Hz)' to 107900000
Click Apply Settings
Click Start Scan

