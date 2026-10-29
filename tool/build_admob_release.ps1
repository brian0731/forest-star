param(
    [Parameter(Mandatory = $true)][string]$ConfigPath,
    [ValidateSet('appbundle', 'apk')][string]$Target = 'appbundle',
    [string]$FlutterExecutable = 'flutter'
)
$ErrorActionPreference = 'Stop'
$projectDirectory = Split-Path $PSScriptRoot -Parent
$resolvedConfig = (Resolve-Path -LiteralPath $ConfigPath).Path
$adConfig = Get-Content -LiteralPath $resolvedConfig -Raw | ConvertFrom-Json
if ($adConfig.ADMOB_PRODUCTION -ne $true -or
    $adConfig.ADMOB_APP_ID -notmatch '^ca-app-pub-\d{16}~\d{10}$' -or
    $adConfig.ADMOB_REWARDED_ID -notmatch '^ca-app-pub-\d{16}/\d{10}$' -or
    $adConfig.ADMOB_APP_ID -match '3940256099942544' -or
    $adConfig.ADMOB_REWARDED_ID -match '3940256099942544' -or
    $adConfig.ADMOB_AUDIENCE -notin @('children', 'general')) {
    throw 'Fill in real AdMob IDs and confirm the audience before building a production release.'
}
Push-Location $projectDirectory
try {
    & $FlutterExecutable build $Target --release "--dart-define-from-file=$resolvedConfig"
    if ($LASTEXITCODE -ne 0) { throw 'Flutter production build failed.' }
} finally { Pop-Location }
