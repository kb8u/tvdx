; Script generated by the Inno Script Studio Wizard.
; SEE THE DOCUMENTATION FOR DETAILS ON CREATING INNO SETUP SCRIPT FILES!

[Messages]
UserInfoDesc=Please enter your user ID.  Name and organization can be anything (they are not used).
UserInfoSerial=&Numeric user ID

[Code]
function IsRDSLoggerInstalled: boolean;
begin
  result := DirExists('C:\SDRSharp\RDSDataLogger');
end;

function InitializeSetup(): Boolean;
var 
  ErrCode: integer;
begin
  result := IsRDSLoggerInstalled;
  if not result then
    if MsgBox('SDR Sharp plugin FM DX RDS Data Logger must be installed for this program to work.  The log directory C:\SDRSharp\RDSDataLogger was not found.  Create it or see the README file if you already have it installed elsewhere.  Would you like to install it now?', mbConfirmation, MB_YESNO) = IDYES
    then begin
      ShellExecAsOriginalUser('open', 'https://www.apritch.co.uk/sdrsharp_plugins.htm',
        '', '', SW_SHOW, ewNoWait, ErrCode);
    end;
  Result := True;
end;

function CheckSerial(Serial: String): Boolean;
begin
  Result := True;
end;

[Setup]
AppName=fm_sdrsharp_reporter
AppVersion=1.0
WizardStyle=modern
UserInfoPage=yes
DisableDirPage=no
DefaultDirName={sd}\FM_SDRSHARP
DefaultGroupName=FM_SDRSHARP
UninstallDisplayIcon={app}\report_file.exe
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
OutputBaseFilename=fm_sdrsharp_install

[Files]
; report_file.exe was created with 'pp -o report_file.exe report_file.pl
Source: "C:\fmdx_src\sdr_sharp\report_file.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "C:\tvdx_src\tvdx\client\win32\fm\sdrsharp\README.TXT"; DestDir: "{app}"; Flags: isreadme
Source: "C:\tvdx_src\tvdx\client\win32\fm\sdrsharp\SDR_SHARP_README.TXT"; DestDir: "{app}";
Source: "C:\tvdx_src\tvdx\client\win32\fm\sdrsharp\ignore_pi.txt"; DestDir: "{app}";

[Run]
Filename: "schtasks"; \
    Parameters: "/Create /F /SC ONSTART /TN ""FM SDRsharp reporter"" /RU ""NT AUTHORITY\NETWORK SERVICE"" /TR ""'{app}\report_file.exe' -t {userinfoserial}"""; \
    Flags: runhidden; \
    StatusMsg: "Running schtasks to run report_file on start up"
; schtasks does not have certain switches so change it with powershell
Filename: "powershell"; \
    Parameters: "-command ""$t=Get-ScheduledTask 'FM SDRsharp reporter';$s=$t.Settings;$s.RestartInterval='PT5M';$s.RestartCount=9999;$s.ExecutionTimeLimit='PT0S';$s.DisallowStartIfOnBatteries=0;$s.StopIfGoingOnBatteries=0;Set-ScheduledTask $t;"; \
    Flags: runhidden; \
    StatusMsg: "Changing scheduled task execution time limit"
Filename: "schtasks"; \
    Parameters: "/Run /TN ""FM SDRsharp reporter"""; \
    Flags: runhidden; \
    StatusMsg: "Starting report_file.exe scheduled task"

[UninstallRun]
Filename: "schtasks"; \
    Parameters: "/End /TN ""FM SDRsharp reporter"""; \
    Flags: runhidden; \
    StatusMsg: "Stopping scheduled task FM SDRsharp reporter"
Filename: "schtasks"; \
    Parameters: "/Delete /F /TN ""FM SDRsharp reporter"""; \
    Flags: runhidden; \
    StatusMsg: "Running schtasks to stop FM SDRsharp reporter on start up"