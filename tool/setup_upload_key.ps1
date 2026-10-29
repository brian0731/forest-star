param(
    [string]$KeyDirectory = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.android/forest-star-upload'),
    [string]$JavaDirectory = 'C:/Program Files/Android/Android Studio/jbr'
)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path -Parent $PSScriptRoot
$propertiesFile = Join-Path $projectDirectory 'android/key.properties'
$keystoreFile = Join-Path $KeyDirectory 'forest-star-upload.jks'
if ((Test-Path -LiteralPath $propertiesFile) -or (Test-Path -LiteralPath $keystoreFile)) {
    throw 'Signing material already exists. Reuse it; this script never replaces an upload key.'
}
New-Item -ItemType Directory -Force -Path $KeyDirectory | Out-Null
# Keep the private key and password accessible to this Windows account only.
$account = [Security.Principal.WindowsIdentity]::GetCurrent().User
$acl = Get-Acl -LiteralPath $KeyDirectory
$acl.SetAccessRuleProtection($true, $false)
$acl.SetAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
    $account, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
Set-Acl -LiteralPath $KeyDirectory -AclObject $acl
$password = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$env:FOREST_UPLOAD_SETUP_PASSWORD = $password
try {
    & (Join-Path $JavaDirectory 'bin/keytool.exe') -genkeypair -noprompt -storetype JKS `
        -keystore $keystoreFile -alias forest-star-upload -keyalg RSA -keysize 3072 -validity 10000 `
        -storepass:env FOREST_UPLOAD_SETUP_PASSWORD -keypass:env FOREST_UPLOAD_SETUP_PASSWORD `
        -dname 'CN=Forest Star Upload'
    if ($LASTEXITCODE -ne 0) { throw 'Upload key generation failed.' }
    & (Join-Path $JavaDirectory 'bin/keytool.exe') -exportcert -rfc -keystore $keystoreFile `
        -alias forest-star-upload -storepass:env FOREST_UPLOAD_SETUP_PASSWORD `
        -file (Join-Path $KeyDirectory 'upload-certificate.pem')
    if ($LASTEXITCODE -ne 0) { throw 'Certificate export failed.' }
    [IO.File]::WriteAllText((Join-Path $KeyDirectory 'store.key-password'), $password, [Text.Encoding]::ASCII)
    $storePath = $keystoreFile.Replace('\', '/')
    $content = "storeFile=$storePath`nstorePassword=$password`nkeyAlias=forest-star-upload`nkeyPassword=$password`n"
    [IO.File]::WriteAllText($propertiesFile, $content, [Text.Encoding]::ASCII)
    $fileAcl = Get-Acl -LiteralPath $propertiesFile
    $fileAcl.SetAccessRuleProtection($true, $false)
    $fileAcl.SetAccessRule([Security.AccessControl.FileSystemAccessRule]::new($account, 'FullControl', 'Allow'))
    Set-Acl -LiteralPath $propertiesFile -AclObject $fileAcl
    Write-Output "Upload key created: $keystoreFile"
    Write-Output "Local signing configuration: $propertiesFile"
    Write-Output 'Back up this private directory securely. No password is printed.'
} finally {
    Remove-Item Env:FOREST_UPLOAD_SETUP_PASSWORD -ErrorAction SilentlyContinue
    Remove-Variable password, content -ErrorAction SilentlyContinue
}
