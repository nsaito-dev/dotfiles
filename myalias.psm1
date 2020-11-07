# Alias for powershell
Set-Alias platon "C:\Users\nsaito\Google Drive\home\Applications\platon\platon.exe"
Set-Alias dysnomia "C:\Users\nsaito\Google Drive\home\Applications\RIETAN_VENUS\Dysnomia\Dysomia.exe"
Set-Alias jmol "C:\Users\nsaito\Google Drive\home\Applications\jmol-14.29.16\jmol.bat"
function cd_home {cd "C:\Users\nsaito"}
Set-Alias cdh cd_home
function cd_gdrive {cd "G:\My Drive"}
Set-Alias cdg cd_gdrive
Set-Alias lst2cif "G:\My Drive\home\Applications\RIETAN_VENUS\lst2cif.exe"
function which {gcm $args[0] | fl}
