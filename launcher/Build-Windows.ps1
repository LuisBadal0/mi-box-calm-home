#requires -Version 7.0
param(
    [string]$AndroidSdkPath = $env:ANDROID_HOME,
    [string]$JavaHomePath = $env:JAVA_HOME,
    [string]$BuildToolsPath,
    [string]$SigningKeyPath = (Join-Path $PSScriptRoot 'calmhome-local.jks'),
    [string]$SigningKeyPassword = $env:CALM_HOME_KEY_PASSWORD
)
$ErrorActionPreference = 'Stop'
if (-not $AndroidSdkPath) { $AndroidSdkPath = $env:ANDROID_SDK_ROOT }
if (-not $AndroidSdkPath -or -not $JavaHomePath) { throw 'Set ANDROID_HOME and JAVA_HOME (Java 17), or supply -AndroidSdkPath and -JavaHomePath.' }
if (-not $BuildToolsPath) { $BuildToolsPath = Join-Path $AndroidSdkPath 'build-tools\34.0.0' }
# A new key gets a random password saved beside it (ignored by Git). Keys made before
# this change keep the legacy development password unless one is supplied.
$passwordFile = [IO.Path]::ChangeExtension($SigningKeyPath, '.password')
if (-not $SigningKeyPassword) {
    if (Test-Path -LiteralPath $passwordFile) {
        $SigningKeyPassword = (Get-Content -LiteralPath $passwordFile -Raw).Trim()
    } elseif (Test-Path -LiteralPath $SigningKeyPath) {
        $SigningKeyPassword = 'local-build-only'
        Write-Warning "$SigningKeyPath has no password file; using the legacy development password."
    } else {
        $bytes = [byte[]]::new(24)
        $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
        $SigningKeyPassword = -join ($bytes | ForEach-Object { $_.ToString('x2') })
        [IO.File]::WriteAllText($passwordFile, $SigningKeyPassword + "`n", [Text.UTF8Encoding]::new($false))
        Write-Output "Created a random signing password in $passwordFile. Keep it private with the key."
    }
}
$androidJar = Join-Path $AndroidSdkPath 'platforms\android-34\android.jar'
foreach ($required in @((Join-Path $JavaHomePath 'bin\javac.exe'),(Join-Path $BuildToolsPath 'aapt2.exe'),$androidJar)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing build dependency: $required" }
}
$env:JAVA_HOME = $JavaHomePath
$env:PATH = (Join-Path $JavaHomePath 'bin') + ';' + $env:PATH
$build = Join-Path $PSScriptRoot ('out\build-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
foreach ($directory in @('classes','dex')) { New-Item -ItemType Directory -Force -Path (Join-Path $build $directory) | Out-Null }
function Invoke-Checked([string]$Program, [string[]]$ArgumentList) {
    & $Program @ArgumentList
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}
Invoke-Checked (Join-Path $BuildToolsPath 'aapt2.exe') @('link','-o',(Join-Path $build 'base.apk'),'-I',$androidJar,'--manifest',(Join-Path $PSScriptRoot 'AndroidManifest.xml'),'--min-sdk-version','21','--target-sdk-version','34')
$sources = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'src') -Recurse -Filter '*.java' | ForEach-Object FullName)
Invoke-Checked (Join-Path $JavaHomePath 'bin\javac.exe') (@('-encoding','UTF-8','-nowarn','-Xlint:-options','-source','1.8','-target','1.8','-bootclasspath',($androidJar + ';' + (Join-Path $BuildToolsPath 'core-lambda-stubs.jar')),'-d',(Join-Path $build 'classes')) + $sources)
$classes = @(Get-ChildItem -LiteralPath (Join-Path $build 'classes') -Recurse -Filter '*.class' | ForEach-Object FullName)
Invoke-Checked (Join-Path $BuildToolsPath 'd8.bat') (@('--min-api','21','--release','--lib',$androidJar,'--output',(Join-Path $build 'dex')) + $classes)
$unsigned = Join-Path $build 'unsigned.apk'
Copy-Item -LiteralPath (Join-Path $build 'base.apk') -Destination $unsigned
$archive = [IO.Compression.ZipFile]::Open($unsigned, [IO.Compression.ZipArchiveMode]::Update)
try { [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,(Join-Path $build 'dex\classes.dex'),'classes.dex') } finally { $archive.Dispose() }
Invoke-Checked (Join-Path $BuildToolsPath 'zipalign.exe') @('-f','4',$unsigned,(Join-Path $build 'aligned.apk'))
if (-not (Test-Path -LiteralPath $SigningKeyPath)) {
    Invoke-Checked (Join-Path $JavaHomePath 'bin\keytool.exe') @('-genkeypair','-keystore',$SigningKeyPath,'-storepass',$SigningKeyPassword,'-keypass',$SigningKeyPassword,'-alias','calmhome','-keyalg','RSA','-keysize','2048','-validity','10000','-dname','CN=Calm Home Local Build')
}
$apk = Join-Path $PSScriptRoot 'out\calm-home.apk'
Invoke-Checked (Join-Path $BuildToolsPath 'apksigner.bat') @('sign','--ks',$SigningKeyPath,'--ks-pass',('pass:' + $SigningKeyPassword),'--out',$apk,(Join-Path $build 'aligned.apk'))
Invoke-Checked (Join-Path $BuildToolsPath 'apksigner.bat') @('verify','--verbose',$apk)
Invoke-Checked (Join-Path $BuildToolsPath 'zipalign.exe') @('-c','4',$apk)
Write-Output "Built and verified: $apk"
Get-FileHash -Algorithm SHA256 -LiteralPath $apk
