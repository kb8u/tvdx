; Script generated by the Inno Script Studio Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

[Messages]
UserInfoDesc=Please enter your user ID and the serial port configured in SDR Console.  Organization is not used.
UserInfoSerial=&Numeric user ID
UserInfoName=&SDR Console serial port name like COM4

[Code]
function IsSDRConsoleInstalled: Boolean;
begin
  result := DirExists('C:\Program Files\SDR-Radio.com (V3)');
end;

function ComPortExists: Boolean;
begin
  Result := RegKeyExists(HKEY_LOCAL_MACHINE, 'HARDWARE\DEVICEMAP\SERIALCOMM');
end;

function InitializeSetup(): Boolean;
var 
  ErrCode: integer;
begin
  result := IsSDRConsoleInstalled;
  if not result then
    if MsgBox('SDR Console was not found in C:  See the README file if you already have it installed elsewhere.  Would you like to install it now?', mbConfirmation, MB_YESNO) = IDYES
    then begin
      ShellExecAsOriginalUser('open', 'https://www.sdr-radio.com/download',
        '', '', SW_SHOW, ewNoWait, ErrCode);
    end;
  result := ComPortExists;
  if not result then
    if MsgBox('SDR Console needs a COM port to control it and none were found.  See SDR_CONSOLE_README.TXT  You probably need to install a virtual serial port such as com0com.  Visit their site now?', mbConfirmation, MB_YESNO) = IDYES
    then begin
      ShellExecAsOriginalUser('open', 'https://sourceforge.net/projects/com0com/',
        '', '', SW_SHOW, ewNoWait, ErrCode);
    end;
  Result := True;
end;


function CheckSerial(Serial: String): Boolean;
begin
  Result := True;
end;

[Setup]
AppName=fm_sdrconsole_reporter
AppVersion=1.0
WizardStyle=modern
UserInfoPage=yes
DefaultUserInfoName=COM4
DefaultUserInfoOrg=FM Live Bandscan participant
DisableDirPage=no
DefaultDirName={sd}\FM_SDRCONSOLE
DefaultGroupName=FM_SDRCONSOLE
UninstallDisplayIcon={app}\report_sqlite.exe
Compression=lzma2
SolidCompression=yes
OutputDir=C:\fmdx_src\installer
; "ArchitecturesAllowed=x64" specifies that Setup cannot run on
; anything but x64.
ArchitecturesAllowed=x64
; "ArchitecturesInstallIn64BitMode=x64" requests that the install be
; done in "64-bit mode" on x64, meaning it should use the native
; 64-bit Program Files directory and the 64-bit view of the registry.
ArchitecturesInstallIn64BitMode=x64
OutputBaseFilename=fm_sdrconsole_install

[Files]
; report_sqlite.exe was created with 'pp -o report_sqlite.exe report_sqlite.pl
Source: "C:\fmdx_src\sdr_console\report_sqlite.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\tvdx_src\tvdx\client\win32\fm\sdrconsole\README.TXT"; DestDir: "{app}"; Flags: isreadme
Source: "C:\tvdx_src\tvdx\client\win32\fm\sdrconsole\SDR_CONSOLE_README.TXT"; DestDir: "{app}";

[Run]
Filename: "schtasks"; \
    Parameters: "/Create /F /SC ONSTART /TN ""FM SDR Console reporter"" /RU SYSTEM /TR ""'{app}\report_sqlite.exe' -t {userinfoserial} -c {userinfoname} -p '{userappdata}\SDR-RADIO.com (V3)'"""; \
    Flags: runhidden; \
    StatusMsg: "Running schtasks to run report_sqlite on start up"
; schtasks does not have certain switches so change it with powershell
Filename: "powershell"; \
    Parameters: "-command ""$t=Get-ScheduledTask 'FM SDR Console reporter';$s=$t.Settings;$s.RestartInterval='PT5M';$s.RestartCount=9999;$s.ExecutionTimeLimit='PT0S';$s.DisallowStartIfOnBatteries=0;$s.StopIfGoingOnBatteries=0;Set-ScheduledTask $t;"; \
    Flags: runhidden; \
    StatusMsg: "Changing scheduled task execution time limit"
Filename: "schtasks"; \
    Parameters: "/Run /TN ""FM SDR Console reporter"""; \
    Flags: runhidden; \
    StatusMsg: "Starting report_sqlite.exe scheduled task"

[UninstallRun]
Filename: "schtasks"; \
    Parameters: "/End /TN ""FM SDR Console reporter"""; \
    Flags: runhidden; \
    StatusMsg: "Stopping scheduled task FM SDR Console reporter"
Filename: "schtasks"; \
    Parameters: "/Delete /F /TN ""FM SDR Console reporter"""; \
    Flags: runhidden; \
    StatusMsg: "Running schtasks to stop FM SDR Console reporter on start up"