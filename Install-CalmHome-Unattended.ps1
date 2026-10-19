#requires -Version 7.0
<#
Running this script authorizes its documented, fixed setup scope without per-step prompts.
The TV's Android debugging authorization cannot be bypassed. No uninstall/data clearing.
#>
[CmdletBinding()]
param(
    [string]$TvIp,
    [ValidateRange(1,65535)][int]$Port = 5555,
    [string]$AdbPath,
    [string]$ApkPath,
    [string]$BackupRoot,
    [switch]$PlanOnly,
    [switch]$CloseWifiDebugging,
    [ValidateRange(1,900)][int]$AuthorizationWaitSeconds = 180,
    [ValidateRange(0,30)][int]$StartupSettleSeconds = 12
)
$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($TvIp)) { throw 'Supply the new box IPv4 address with -TvIp; no target was selected.' }
$ipAddress = $null
if (-not [Net.IPAddress]::TryParse($TvIp, [ref]$ipAddress) -or $ipAddress.AddressFamily -ne 'InterNetwork') { throw 'Supply the new box IPv4 address with -TvIp.' }
$octets = $ipAddress.GetAddressBytes()
if (-not ($octets[0] -eq 10 -or ($octets[0] -eq 192 -and $octets[1] -eq 168) -or ($octets[0] -eq 172 -and $octets[1] -ge 16 -and $octets[1] -le 31))) { throw 'Only private local-network target addresses are supported.' }
$script:Target = '{0}:{1}' -f $TvIp,$Port
$script:Package = 'com.luisbadalo.calmhome'
$script:Stock = 'com.google.android.tvlauncher'
$script:Analytics = 'com.miui.tv.analytics'
$script:HomeComponent = "$($script:Package)/.MainActivity"
$expectedHash = 'C904CEE4AFE38284A0E94ADE2A0A218C89AC4AA0559B2054648A29E9C2F83C43'
$script:Apps = 'com.hitv.explore,dev.fredol.open_tv,org.localsend.localsend_app,com.surfshark.vpnclient.android,tv.twitch.android.app,org.videolan.vlc'
if (-not $AdbPath) {
    foreach ($candidate in @('platform-tools\adb.exe','tools\platform-tools\adb.exe')) {
        $candidatePath = Join-Path $PSScriptRoot $candidate
        if (Test-Path -LiteralPath $candidatePath) { $AdbPath = $candidatePath; break }
    }
}
if (-not $ApkPath) {
    foreach ($candidate in @('calm-home.apk','tv-detox\out\calm-home.apk')) {
        $candidatePath = Join-Path $PSScriptRoot $candidate
        if (Test-Path -LiteralPath $candidatePath) { $ApkPath = $candidatePath; break }
    }
}
if (-not $AdbPath -or -not $ApkPath) { throw 'Extract the reviewed APK and official Android Platform Tools beside this script, or supply -AdbPath and -ApkPath.' }
$script:Adb = (Resolve-Path -LiteralPath $AdbPath).Path
$ApkPath = (Resolve-Path -LiteralPath $ApkPath).Path
if ((Get-FileHash -LiteralPath $ApkPath -Algorithm SHA256).Hash -ne $expectedHash) { throw 'Unexpected APK checksum. No TV action was performed.' }
if (-not $BackupRoot) { $BackupRoot = Join-Path $PSScriptRoot 'tv-backup' }
$runId = (Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,6)
$script:RunFolder = Join-Path $BackupRoot ("unattended-$TvIp-$runId")
New-Item -ItemType Directory -Force -Path $script:RunFolder | Out-Null
$script:Changes = [Collections.Generic.List[object]]::new()
$script:Journal = [ordered]@{ Target=$script:Target; Started=(Get-Date).ToString('o'); Status='preflight'; Authorization='Explicit invocation of noninteractive fixed-scope installer'; PlanOnly=[bool]$PlanOnly; APK_SHA256=$expectedHash; Changes=$script:Changes; BackupLimit='Settings, package state and readable APKs; no firmware, account/private-app-data or guaranteed disaster recovery image.' }
$script:Before = $null
function Save-Journal { $script:Journal | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath (Join-Path $script:RunFolder 'journal.json') -Encoding utf8 }
function Invoke-Tool([string[]]$Arguments, [int]$Timeout=30, [switch]$Soft) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $script:Adb
    # A .ps1 adapter is supported for offline mock tests; production uses official adb.exe.
    if ([IO.Path]::GetExtension($script:Adb) -eq '.ps1') {
        $info.FileName = (Get-Process -Id $PID).Path
        foreach ($argValue in @('-NoProfile','-File',$script:Adb)) { $info.ArgumentList.Add($argValue) }
    }
    foreach ($argValue in $Arguments) { $info.ArgumentList.Add($argValue) }
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $process = [Diagnostics.Process]::new(); $process.StartInfo=$info
    try {
        [void]$process.Start()
        $stdoutTask=$process.StandardOutput.ReadToEndAsync(); $stderrTask=$process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($Timeout*1000)) { $process.Kill($true); throw "ADB command timed out: $($Arguments -join ' ')" }
        $output=$stdoutTask.GetAwaiter().GetResult().Trim(); $errorText=$stderrTask.GetAwaiter().GetResult().Trim()
        if ($process.ExitCode -ne 0 -and -not $Soft) { throw "ADB failed ($($Arguments -join ' ')): $output $errorText" }
        return [pscustomobject]@{ Code=$process.ExitCode; Out=$output; Error=$errorText }
    } finally { $process.Dispose() }
}
function Adb([string[]]$Arguments, [int]$Timeout=30) { (Invoke-Tool -Arguments (@('-s',$script:Target)+$Arguments) -Timeout $Timeout).Out }
function Wait-ForAuthorization {
    Write-Host "Connecting to $script:Target. Keep the TV awake on its HDMI input."
    Write-Host 'If the TV shows "Allow USB debugging?" (also used over Wi-Fi), select "Always allow from this computer", then "Allow". Already trusted connections continue without another dialog.'
    Write-Host "Waiting up to $AuthorizationWaitSeconds seconds; setup continues automatically after authorization. No TV settings/apps will change while waiting."
    $deadline=(Get-Date).AddSeconds($AuthorizationWaitSeconds)
    $nextConnect=Get-Date; $lastState=''; $notifiedUnauthorized=$false
    do {
        if ((Get-Date) -ge $nextConnect -and $lastState -notmatch 'unauthorized') {
            try { [void](Invoke-Tool @('connect',$script:Target) -Timeout 8 -Soft) } catch { $lastState=$_.Exception.Message }
            $nextConnect=(Get-Date).AddSeconds(10)
        }
        try {
            $state=Invoke-Tool @('-s',$script:Target,'get-state') -Timeout 8 -Soft
            if ($state.Code -eq 0 -and $state.Out -eq 'device') {
                $script:Journal.ConnectionStatus='Authorized'; Save-Journal
                Write-Host 'TV debugging authorized. Continuing setup...'; return
            }
            $lastState=($state.Out+' '+$state.Error).Trim()
        } catch { $lastState=$_.Exception.Message }
        if ($lastState -match 'unauthorized' -and -not $notifiedUnauthorized) {
            Write-Host 'The TV is reachable but has not approved this debugging key. Use the TV remote to select Allow on its authorization dialog.'
            Write-Host 'No dialog? Open Settings > Device Preferences > Developer options; toggle USB debugging off/on, enable network debugging if available, and return to the TV screen. Menu names can vary.'
            $notifiedUnauthorized=$true
        }
        if ((Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
    } while ((Get-Date) -lt $deadline)
    $script:Journal.ConnectionStatus=$lastState; Save-Journal
    throw "Debugging authorization/connection timed out for $script:Target. No TV settings/apps changed. Keep the TV awake, check its IP and enable USB/network debugging in Developer options, then rerun and accept Allow on the TV. Do not reset ADB keys or revoke other authorizations. Last state: $lastState"
}
function Shell([string[]]$Arguments) { Adb -Arguments (@('shell')+$Arguments) }
function Save-Text([string]$Name,[string]$Value) { [IO.File]::WriteAllText((Join-Path $script:RunFolder $Name),$Value,[Text.UTF8Encoding]::new($false)) }
function Packages([string]$Text) { @($Text -split '\r?\n' | Where-Object { $_ -match '^package:' } | ForEach-Object { (($_ -replace '^package:','') -split '=')[-1].Split(' ')[0] }) }
function Actual-Home { $text=Shell @('cmd','package','resolve-activity','--brief','--user','0','-a','android.intent.action.MAIN','-c','android.intent.category.HOME'); $match=[regex]::Match($text,'(?m)^([\w.]+/[\w.]+)\s*$'); if (-not $match.Success) { throw "Cannot identify actual Home: $text" }; $match.Groups[1].Value }
function Resumed { ((Shell @('dumpsys','activity','activities')) -split '\r?\n' | Where-Object { $_ -match 'ResumedActivity' }) -join "`n" }
function Package-State([string]$Package) {
    $details=Shell @('dumpsys','package',$Package)
    $match=[regex]::Match($details,'User 0:[^\r\n]*installed=true[^\r\n]*enabled=(\d+)')
    if (-not $match.Success) { throw "Cannot record original enabled state for $Package" }
    [int]$match.Groups[1].Value
}
function Restore-StateArgs([string]$Package,[int]$State) {
    switch ($State) { 0 { @('shell','pm','default-state','--user','0',$Package) }; 1 { @('shell','pm','enable','--user','0',$Package) }; 2 { @('shell','pm','disable','--user','0',$Package) }; 3 { @('shell','pm','disable-user','--user','0',$Package) }; 4 { @('shell','pm','disable-until-used','--user','0',$Package) }; default { throw 'Unsupported original package state' } }
}
function Apply-Change([string]$Name,[string[]]$Arguments,[string[]]$Undo,[object]$Original=$null) {
    $entry=[ordered]@{ Name=$Name; Arguments=$Arguments; UndoArguments=$Undo; Original=$Original; Status='applying'; Time=(Get-Date).ToString('o') }
    $script:Changes.Add($entry); Save-Journal
    $entry.Output=Adb -Arguments $Arguments -Timeout 120
    $entry.Status='applied'; Save-Journal
}
function Snapshot {
    $state=[ordered]@{}
    $queries=[ordered]@{
        Packages=@('pm','list','packages','--user','0'); Disabled=@('pm','list','packages','-d','--user','0')
        Keyboard=@('settings','get','secure','default_input_method'); Bluetooth=@('settings','get','global','bluetooth_on')
        Hdmi=@('getprop','init.svc.hdmicecd'); Accessibility=@('settings','get','secure','enabled_accessibility_services')
        AccessibilityEnabled=@('settings','get','secure','accessibility_enabled')
        ScreenOff=@('settings','get','system','screen_off_timeout'); Sleep=@('settings','get','secure','sleep_timeout')
        WindowAnimation=@('settings','get','global','window_animation_scale'); TransitionAnimation=@('settings','get','global','transition_animation_scale')
        Animator=@('settings','get','global','animator_duration_scale'); Screensaver=@('settings','get','secure','screensaver_enabled')
    }
    foreach ($key in $queries.Keys) { $state[$key]=Shell $queries[$key] }
    $state.Home=Actual-Home
    $state
}
function Memory {
    $text=Shell @('cat','/proc/meminfo'); $values=[ordered]@{}
    foreach ($key in @('MemTotal','MemAvailable','MemFree')) {
        $match=[regex]::Match($text,"(?m)^${key}:\s+(\d+)")
        if (-not $match.Success) { throw 'Incomplete RAM reading' }
        $values[$key]=[int64]$match.Groups[1].Value
    }
    $values
}
function Screenshot([string]$Name) {
    $remote="/data/local/tmp/calm-home-$runId-$Name.png"
    [void](Shell @('screencap','-p',$remote))
    [void](Adb @('pull',$remote,(Join-Path $script:RunFolder "$Name.png")))
}
function Check-UI {
    if ((Resumed) -notmatch 'com\.luisbadalo\.calmhome/') { throw 'Calm Home is not in the foreground' }
    for ($attempt=0; $attempt -lt 3; $attempt++) {
        $remote="/data/local/tmp/calm-home-$runId-$attempt.xml"
        try {
            [void](Shell @('uiautomator','dump',$remote)); $raw=Shell @('cat',$remote)
            [xml]$xml=$raw; $nodes=@($xml.SelectNodes('//node'))
            $texts=@($nodes | ForEach-Object { $_.GetAttribute('text') })
            if ($texts -contains 'Play Store' -and $texts -contains 'Settings' -and @($texts | Where-Object { $_ -match '^\d{1,2}:\d{2}$' }).Count -gt 0 -and @($nodes | Where-Object { $_.GetAttribute('clickable') -eq 'true' }).Count -ge 2) { Save-Text 'calm-home-ui.xml' $raw; return }
        } catch { if ($attempt -eq 2) { throw "Cannot verify Calm Home UI; stock Home will not be disabled. $($_.Exception.Message)" } }
    }
    throw 'Calm Home clock/utility tiles could not be verified; stock Home will not be disabled.'
}
function Test-Home {
    [void](Shell @('am','start','-a','android.settings.SETTINGS')); Start-Sleep -Milliseconds 600
    [void](Shell @('input','keyevent','3')); Start-Sleep -Milliseconds 600
    ((Resumed) -match 'com\.luisbadalo\.calmhome/')
}
function Set-Setting([string]$Name,[string]$Namespace,[string]$Key,[string]$Original) {
    if ($Original -eq '0') { return }
    $undo=if ($Original -eq 'null' -or $Original -eq '') { @('shell','settings','delete',$Namespace,$Key) } else { @('shell','settings','put',$Namespace,$Key,$Original) }
    Apply-Change $Name @('shell','settings','put',$Namespace,$Key,'0') $undo $Original
    if ((Shell @('settings','get',$Namespace,$Key)) -ne '0') { throw "Setting verification failed: $Key" }
}
function Write-Undo {
    $lines=[Collections.Generic.List[string]]::new()
    $lines.Add('# Per-box undo and setup record'); $lines.Add(''); $lines.Add("Target: $($script:Target). Status: $($script:Journal.Status).")
    $lines.Add('Keep analytics disabled during a launcher-only rollback. Re-enable/restore/open the ORIGINAL Home before disabling Calm Home. Never uninstall or bulk-import another box settings. Re-enable debugging on the TV first if it was closed.')
    if ($script:Before -and $script:Before.Home -eq 'com.google.android.tvlauncher/.MainActivity') {
        $lines.Add(''); $lines.Add('Original Home: '+$script:Before.Home)
        if ($script:Journal.Contains('StockOriginalState')) { $lines.Add('Restore original stock package state: adb -s '+$script:Target+' '+((Restore-StateArgs $script:Stock $script:Journal.StockOriginalState) -join ' ')) }
        $lines.Add('Restore preferred Home: adb -s '+$script:Target+' shell pm set-home-activity --user 0 '+$script:Before.Home)
        $lines.Add('Open and verify original Home: adb -s '+$script:Target+' shell am start -n '+$script:Before.Home)
        $lines.Add('Only AFTER original Home works, optionally disable Calm Home: adb -s '+$script:Target+' shell pm disable-user --user 0 '+$script:Package)
    } elseif ($script:Before) {
        $lines.Add('Calm Home was already the original Home before this run. Do not disable it using this run as a launcher rollback. Consult the first setup journal and re-enable/open/verify stock Home before considering that change.')
    }
    $lines.Add(''); $lines.Add('## Individual original values / optional undo')
    foreach ($change in $script:Changes) { $lines.Add('- '+$change.Name+' ['+$change.Status+']: adb -s '+$script:Target+' '+($change.UndoArguments -join ' ')) }
    $lines.Add(''); $lines.Add('Original sleep times were preserved and need no undo. Full original settings, package states, readable APKs and checksums are in this folder. These are not a full firmware/private-data backup. See journal.json for exact applied/skipped/failed state and verifications. Unattended setup did not install missing user apps.')
    [IO.File]::WriteAllLines((Join-Path $script:RunFolder 'UNDO.md'),$lines,[Text.UTF8Encoding]::new($false))
}
function Recover-OnFailure {
    $attempts=[Collections.Generic.List[string]]::new()
    if ($script:Before -and $script:Before.Home -eq 'com.google.android.tvlauncher/.MainActivity' -and $script:Changes.Count -gt 0) {
        try {
            if ($script:Journal.Contains('StockOriginalState')) { [void](Adb (Restore-StateArgs $script:Stock $script:Journal.StockOriginalState)) }
            [void](Shell @('pm','set-home-activity','--user','0',$script:Before.Home)); [void](Shell @('am','start','-n',$script:Before.Home)); $attempts.Add('Original stock Home restored; Calm Home kept installed.')
        } catch { $attempts.Add('Home recovery could not be verified: '+$_.Exception.Message) }
        foreach ($change in $script:Changes) {
            if ($change.Name -in @('window-animation','transition-animation','animator','screensaver')) {
                try { [void](Adb $change.UndoArguments); $change.Status='rolled back after failure' } catch { $attempts.Add('Setting recovery failed: '+$change.Name) }
            }
        }
    }
    $script:Journal.Recovery=$attempts
}
Save-Journal
try {
    Wait-ForAuthorization
    $model=Shell @('getprop','ro.product.model'); $api=Shell @('getprop','ro.build.version.sdk'); $user=Shell @('am','get-current-user')
    $script:Journal.Device=[ordered]@{ Model=$model; API=$api; Serial=(Shell @('getprop','ro.serialno')); User=$user }
    if ($model -ne 'MIBOX4' -or $api -ne '28' -or $user -ne '0') { throw 'Automatic mode supports only the tested MIBOX4 / Android 9 / user 0. Use the guided workflow for this device.' }
    $script:Before=Snapshot; $script:Journal.Before=$script:Before; $script:Journal.InitialMemoryKiB=Memory; Save-Journal
    $packages=Packages $script:Before.Packages; $disabled=Packages $script:Before.Disabled
    if ($packages -contains 'com.spocky.projengmenu') { throw 'Projectivy is present; this is a fresh-box installer, not an automatic migration/uninstaller.' }
    if ($script:Before.Home -notin @('com.google.android.tvlauncher/.MainActivity',$script:HomeComponent)) { throw 'Unexpected original Home. No launcher change will be guessed.' }
    foreach ($protected in @('com.android.vending','com.google.android.gms','com.google.android.gsf','com.android.tv.settings')) { if ($packages -notcontains $protected -or $disabled -contains $protected) { throw "Required protected component unavailable: $protected" } }
    $keyboardPackage=($script:Before.Keyboard -split '/')[0]
    if (-not $keyboardPackage -or $packages -notcontains $keyboardPackage -or $disabled -contains $keyboardPackage) { throw 'The current keyboard could not be verified.' }
    foreach ($key in @('WindowAnimation','TransitionAnimation','Animator','Screensaver')) { if ($script:Before[$key] -notmatch '^(null|-?\d+(\.\d+)?)?$') { throw "Unexpected original setting: $key" } }
    $script:Journal.StockOriginalState=Package-State $script:Stock
    if ($packages -contains $script:Analytics) { $script:Journal.AnalyticsOriginalState=Package-State $script:Analytics }
    $catalogPath=Join-Path $PSScriptRoot 'app-catalog.json'; $catalog=if (Test-Path -LiteralPath $catalogPath) { Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
    $inventory=@(foreach ($packageId in $packages) { $entry=$catalog[$packageId]; [pscustomobject]@{ Package=$packageId; Name=$(if($entry){$entry.Name}else{'Unidentified component; keep enabled'}); Category=$(if($entry){$entry.Category}else{'keep'}); Purpose=$(if($entry){$entry.Purpose}else{'Purpose not established; no automatic disable'}); OriginallyDisabled=($disabled -contains $packageId) } })
    $inventory | Export-Csv -LiteralPath (Join-Path $script:RunFolder 'inventory.csv') -NoTypeInformation -Encoding utf8
    $inventoryLines=@('# App inventory (candidates are not automatically disabled)','')
    foreach ($category in @('optional','keep','use')) { $inventoryLines += "## $category"; foreach($item in @($inventory | Where-Object Category -eq $category | Sort-Object Name)) { $inventoryLines += '- '+$item.Name+' ('+$item.Package+'): '+$item.Purpose }; $inventoryLines += '' }
    Save-Text 'APP-INVENTORY.md' ($inventoryLines -join "`n")
    foreach ($namespace in @('global','secure','system')) { Save-Text "settings-$namespace.txt" (Shell @('settings','list',$namespace)) }
    Save-Text 'package-details.txt' (Shell @('dumpsys','package')); Save-Text 'preferred-home.xml' (Shell @('dumpsys','package','preferred-xml'))
    $script:Journal.MissingUserApps=@($script:Apps.Split(',') | Where-Object { $packages -notcontains $_ })
    if ($PlanOnly) { $script:Journal.Status='plan only; no TV changes'; Save-Journal; Write-Undo; Write-Host "Read-only plan saved: $script:RunFolder"; return }
    Write-Host 'Saving readable APKs before changes...'
    $exports=[Collections.Generic.List[object]]::new()
    foreach ($packageId in $packages) {
        $destination=Join-Path $script:RunFolder "apks\$packageId"; New-Item -ItemType Directory -Force -Path $destination | Out-Null
        foreach ($line in ((Shell @('pm','path',$packageId)) -split '\r?\n')) {
            if ($line -notmatch '^package:(/.+\.apk)$') { continue }; $remote=$Matches[1]; $local=Join-Path $destination ([IO.Path]::GetFileName($remote))
            $pull=Invoke-Tool -Arguments @('-s',$script:Target,'pull',$remote,$local) -Timeout 120 -Soft
            $exports.Add([ordered]@{ Package=$packageId; Remote=$remote; Local=$local; Success=($pull.Code -eq 0); Error=$pull.Error; SHA256=$(if($pull.Code -eq 0 -and (Test-Path -LiteralPath $local)){(Get-FileHash -LiteralPath $local -Algorithm SHA256).Hash}else{$null}) })
        }
    }
    Save-Text 'apk-backup.json' ($exports | ConvertTo-Json -Depth 5)
    if ($packages -contains $script:Package) {
        if ($disabled -contains $script:Package) { throw 'Existing Calm Home is disabled; use guided mode to decide whether to re-enable it.' }
        $existingPath=(Shell @('pm','path',$script:Package)) -replace '^package:',''; if ($existingPath -match '\r|\n') { throw 'Unexpected split APK for Calm Home' }
        $existingLocal=Join-Path $script:RunFolder 'installed-calm-home.apk'; [void](Adb @('pull',$existingPath,$existingLocal))
        if ((Get-FileHash -LiteralPath $existingLocal -Algorithm SHA256).Hash -ne $expectedHash) { throw 'A different Calm Home build is already installed. It will not be overwritten automatically.' }
        [void](Shell @('am','start','-n',$script:HomeComponent))
    } else {
        Apply-Change 'install-calm-home' @('install',$ApkPath) @('shell','pm','disable-user','--user','0',$script:Package) 'not installed'
        if ((Packages (Shell @('pm','list','packages','--user','0'))) -notcontains $script:Package) { throw 'Calm Home install verification failed' }
        Apply-Change 'configure-app-list' @('shell','am','start','-n',$script:HomeComponent,'--es','apps',$script:Apps) @('shell','am','start','-n',$script:HomeComponent,'--es','apps','auto') 'fresh app; built-in list matches saved list'
    }
    Check-UI; Screenshot 'trial-home'
    if ($packages -contains $script:Analytics -and $disabled -notcontains $script:Analytics) {
        Apply-Change 'disable-xiaomi-analytics' @('shell','pm','disable-user','--user','0',$script:Analytics) (Restore-StateArgs $script:Analytics $script:Journal.AnalyticsOriginalState) $script:Journal.AnalyticsOriginalState
    }
    if ((Actual-Home) -ne $script:HomeComponent) {
        Apply-Change 'preferred-home' @('shell','pm','set-home-activity','--user','0',$script:HomeComponent) @('shell','pm','set-home-activity','--user','0',$script:Before.Home) $script:Before.Home
    }
    if (-not (Test-Home)) {
        if ((Actual-Home) -ne 'com.google.android.tvlauncher/.MainActivity') { throw 'Unexpected app won Home; no additional package will be disabled.' }
        Apply-Change 'disable-stock-home' @('shell','pm','disable-user','--user','0',$script:Stock) (Restore-StateArgs $script:Stock $script:Journal.StockOriginalState) $script:Journal.StockOriginalState
        if (-not (Test-Home)) { throw 'Home failed after the narrow stock-launcher change' }
    }
    Set-Setting 'window-animation' 'global' 'window_animation_scale' $script:Before.WindowAnimation
    Set-Setting 'transition-animation' 'global' 'transition_animation_scale' $script:Before.TransitionAnimation
    Set-Setting 'animator' 'global' 'animator_duration_scale' $script:Before.Animator
    Set-Setting 'screensaver' 'secure' 'screensaver_enabled' $script:Before.Screensaver
    $script:Journal.BeforeRestartMemoryKiB=Memory; $bootBefore=Shell @('cat','/proc/sys/kernel/random/boot_id'); $script:Journal.BeforeBootId=$bootBefore
    if ($script:Changes.Count -gt 0) {
        $script:Journal.Status='restarting'; Save-Journal; Write-Undo
        [void](Adb @('reboot')); Write-Host 'Restart sent. Waiting for startup...'; $deadline=(Get-Date).AddMinutes(4); $ready=$false
        do {
            Start-Sleep -Seconds 3
            try { [void](Invoke-Tool @('connect',$script:Target) -Timeout 8); $newBoot=Shell @('cat','/proc/sys/kernel/random/boot_id'); $ready=($newBoot -ne $bootBefore -and (Shell @('getprop','sys.boot_completed')) -eq '1') } catch { $ready=$false }
        } until ($ready -or (Get-Date) -gt $deadline)
        if (-not $ready) { throw 'Restart reconnection timed out; recovery requires a reachable box.' }
        if ($StartupSettleSeconds -gt 0) { Start-Sleep -Seconds $StartupSettleSeconds }
        $script:Journal.AfterBootId=$newBoot; $script:Journal.Rebooted=$true
    } else { $script:Journal.Rebooted=$false; $script:Journal.RebootSkipped='Already configured; no persistent changes made.' }
    $after=Snapshot; $script:Journal.After=$after; $script:Journal.AfterRestartMemoryKiB=Memory
    $afterPackages=Packages $after.Packages; $afterDisabled=Packages $after.Disabled
    if (@($packages | Where-Object { $afterPackages -notcontains $_ }).Count -gt 0) { throw 'An original package is missing' }
    $allowed=@($disabled)+@($script:Stock,$script:Analytics)
    if (@($afterDisabled | Where-Object { $allowed -notcontains $_ }).Count -gt 0) { throw 'Unexpected newly disabled package' }
    foreach($protected in @('com.android.vending','com.google.android.gms','com.google.android.gsf','com.android.tv.settings',$keyboardPackage)) { if($afterDisabled -contains $protected -or $afterPackages -notcontains $protected){throw "Protected app verification failed: $protected"} }
    foreach($key in @('Keyboard','Bluetooth','Hdmi','Accessibility','AccessibilityEnabled','ScreenOff','Sleep')) { if($after[$key] -ne $script:Before[$key]) { throw "Protected/original setting changed: $key" } }
    foreach($key in @('WindowAnimation','TransitionAnimation','Animator','Screensaver')) { if($after[$key] -ne '0') { throw "Setting did not persist: $key" } }
    if ($packages -contains $script:Analytics -and $afterDisabled -notcontains $script:Analytics) { throw 'Analytics disable did not persist' }
    if (-not (Test-Home)) { throw 'Home did not persist after restart' }
    Check-UI; Screenshot 'final-home'
    $script:Journal.Status='complete; setup and persistence checks passed'; Save-Journal; Write-Undo
    if ($CloseWifiDebugging) {
        $script:Journal.DebuggingClosure='requested; switching ADB to USB mode'; Save-Journal
        try { [void](Adb @('usb')) } catch { $script:Journal.DebuggingCommandError=$_.Exception.Message }
        Start-Sleep -Seconds 2
        $client=[Net.Sockets.TcpClient]::new(); $open=$false
        try { $task=$client.ConnectAsync($TvIp,$Port); if($task.Wait(2000)){$open=$client.Connected} } catch { $open=$false } finally { $client.Dispose() }
        $script:Journal.DebuggingClosure=if($open){'Wireless port still reachable; could not verify closure'}else{'Wireless ADB port no longer reachable; USB debugging not revoked'}
        if($open){$script:Journal.Status='setup complete; wireless debugging closure needs attention'}
    } else { $script:Journal.DebuggingClosure='not requested; ADB remains available. Rerun with -CloseWifiDebugging when wanted.' }
    Save-Journal; Write-Undo
    $b=$script:Journal.BeforeRestartMemoryKiB; $a=$script:Journal.AfterRestartMemoryKiB
    Write-Host ("Available RAM: {0:N0} -> {1:N0} MiB; completely unused: {2:N0} -> {3:N0} MiB (fluctuates)." -f ($b.MemAvailable/1024),($a.MemAvailable/1024),($b.MemFree/1024),($a.MemFree/1024))
    Write-Host "Result: $($script:Journal.Status). Report/undo: $script:RunFolder"
} catch {
    $script:Journal.Status='failed; stopped without further setup'; $script:Journal.Error=$_.Exception.Message
    Recover-OnFailure; Save-Journal; Write-Undo
    throw "Setup stopped: $($script:Journal.Error). Per-box evidence and recovery: $script:RunFolder"
}
