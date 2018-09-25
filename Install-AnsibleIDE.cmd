@ECHO off
:: Set up a Windows PC for development of Ansible playbooks.
:: Installs Visual Studio Code, Chocolatey package manager, WSL Ubuntu 18.04, Docker, Virtualbox, Vagrant and other programs ready to use.
:: For usage ideas, see: https://www.frostbyte.us/configure-an-ansible-testing-system-on-windows-part-1/

:: AUTHORS
:: Jannik Grube <jann497f@elevcampus.dk>
:: Kasper Beiter Lauridsen <kasp9518@elevcampus.dk>

:: TODO
:: - output informative information to screen, keep user informed of whats going on
:: - maybe limit output of some programs / screen candy
:: - check if features are enabled, programs installed and boot manager entries present before going on (especially last one - tricky, no powershell module for that!)
:: - remove ubuntu appx after install (check successful install?)


:: Session handling
:: - stage 1 needs to run in admin, stage2 in user context.
:: - check if stage 1 file exists and goto stage2 if it does
IF EXIST %TEMP%\stage1.txt (
    GOTO STAGE2
) ELSE (
    GOTO STAGE1
)

:STAGE1
:: Stage 1 - ADMIN context
:: - check if running as administrator
::   see: https://stackoverflow.com/questions/4051883/batch-script-how-to-check-for-admin-rights#11995662
NET SESSION > NUL 2>&1
IF %ERRORLEVEL% == 0 (
:: - enable hyper-v w/o restart
powershell Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
:: - enable wsl w/o restart
powershell Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
:: - update bootloader with "WITH Hyper-V" option to be able to switch between different virt progs
bcdedit /set {current} hypervisorlaunchtype auto
bcdedit /copy {current} /d "Windows WITH Hyper-V"
bcdedit /set {current} hypervisorlaunchtype off
:: - install chocolatey package manager
::   see: https://chocolatey.org/
powershell -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
:: - install w/ choco
cinst -y git git-lfs vagrant docker docker-compose docker-for-windows vscode virtualbox
:: - persist stage 1 complete
COPY /y NUL %TEMP%\stage1.txt > NUL
:: - copy self into calling user's autostart
COPY "%~f0" "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\"
:: - restart computer
ECHO Computer needs to restart to continue. Ready?
PAUSE
powershell Restart-Computer
) ELSE (
    ECHO Failure: Current permissions inadequate. Please run as Administrator.
    PAUSE
)

:STAGE2
:: Stage 2 - USER context
:: - check if running as user
NET SESSION > NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
:: - install vscode ansible and vagrant extensions
code --install-extension vscoss.vscode-ansible
code --install-extension bbenoist.vagrant
code --install-extension ms-vscode.powershell
:: - download ubuntu-1804.appx
curl.exe -L -o %USERPROFILE%\Downloads\ubuntu-1804.appx https://aka.ms/wsl-ubuntu-1804
:: - add ubuntu-18.04.appx
powershell Add-AppxPackage %USERPROFILE%\Downloads\ubuntu-1804.appx
:: - run ubuntu-1804 installer
ubuntu1804 install
:: - run linux commands in one batch, getting ready to use ansible in wsl to manage windows machines :-)
::   see: https://www.frostbyte.us/ansible-integrated-development-environment-setup-on-windows/
wsl sudo -H sh -c "apt-add-repository -yu ppa:ansible/ansible && apt-get -y install ansible python-pip libkrb5-dev krb5-user && pip install --upgrade pip && pip install --upgrade pyvmomi pywinrm[kerberos] pywinrm[credssp] && apt-get -y upgrade"
:: - clean up stagefile
DEL %TEMP%\stage1.txt
:: - clean up autostart entry / delete self
::   see: https://stackoverflow.com/a/20333575
(GOTO) 2>NUL & DEL "%~f0"
PAUSE
) ELSE (
    ECHO Failure: Not running as user. Please run again as normal user.
    PAUSE
)
