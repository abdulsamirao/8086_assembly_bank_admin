$ErrorActionPreference = 'Stop'

$root = 'C:\practical\CALD_PROJECT'
& (Join-Path $PSScriptRoot 'BOOT86.PS1') `
    -ToolDirectory (Join-Path $root 'TOOLS\TASM')
$dosbox = 'C:\Users\abdul\AppData\Local\Programs\DOSBox Staging\dosbox.exe'
$checkDirectory = Join-Path $root 'TOOLS\CHK8086'
$stdout = Join-Path $root 'TOOLS\HEADLESS.OUT'
$stderr = Join-Path $root 'TOOLS\HEADLESS.LOG'
$testInputs = @(Get-ChildItem (Join-Path $root 'TESTS') -Filter '*.IN' -File)
if ($testInputs.Count -eq 0) {
    throw 'No test input files found in TESTS.'
}

$lintPath = Join-Path $root 'TOOLS\LINT8086.PS1'
$lintOutput = & (Join-Path $PSHOME 'powershell.exe') -NoProfile `
    -ExecutionPolicy Bypass -File $lintPath -SourceRoot (Join-Path $root 'SRC') 2>&1
$lintExit = $LASTEXITCODE
if ($lintExit -ne 0) {
    $lintOutput | ForEach-Object { Write-Output $_ }
    throw '8086 source lint failed.'
}
$lintOutput | ForEach-Object { Write-Output $_ }

$caseScriptPath = Join-Path $root 'TOOLS\RUNCASES.BAT'
$caseLines = [Collections.Generic.List[string]]::new()
foreach ($input in $testInputs) {
    if ($input.BaseName -notmatch '^[A-Za-z0-9_]{1,8}$') {
        throw "Test name must use an 8.3-compatible stem: $($input.Name)."
    }
    $expected = Join-Path $input.DirectoryName ($input.BaseName + '.EXP')
    if (-not (Test-Path $expected)) {
        throw "Missing expected output for $($input.Name): $expected."
    }
    $argumentPath = Join-Path $input.DirectoryName ($input.BaseName + '.ARG')
    $argumentText = ''
    if (Test-Path $argumentPath) {
        $argumentText = [IO.File]::ReadAllText($argumentPath).TrimEnd([char[]]"`r`n")
    }
    $executableName = $input.BaseName
    if (-not (Test-Path (Join-Path $root ("TOOLS\" + $executableName + '.ASM')))) {
        $executableName = 'BANK'
    }
    $label = 'CASE_' + $input.BaseName.ToUpperInvariant()
    $appCommand = "C:\TOOLS\$executableName.EXE"
    if ($argumentText.Length -gt 0) {
        $appCommand += ' ' + $argumentText
    }
    $appCommand += " < C:\TESTS\$($input.BaseName).IN > C:\TOOLS\$($input.BaseName).OUT"
    $caseLines.Add($appCommand)
    $caseLines.Add("if errorlevel 2 goto ${label}_2")
    $caseLines.Add("if errorlevel 1 goto ${label}_1")
    $caseLines.Add("echo 0 > C:\TOOLS\$($input.BaseName).ERR")
    $caseLines.Add("goto ${label}_DONE")
    $caseLines.Add(":${label}_2")
    $caseLines.Add("echo 2 > C:\TOOLS\$($input.BaseName).ERR")
    $caseLines.Add("goto ${label}_DONE")
    $caseLines.Add(":${label}_1")
    $caseLines.Add("echo 1 > C:\TOOLS\$($input.BaseName).ERR")
    $caseLines.Add("goto ${label}_DONE")
    $caseLines.Add(":${label}_DONE")
}
[IO.File]::WriteAllLines($caseScriptPath, $caseLines, [Text.Encoding]::ASCII)

$null = New-Item -ItemType Directory -Force -Path $checkDirectory
$invalidSources = @{
    'BADPUSHA.ASM' = @(
        '.8086', '.model small', '.code', 'MAIN PROC', '    PUSHA',
        '    RET', 'MAIN ENDP', 'END MAIN'
    )
    'BADSHIFT.ASM' = @(
        '.8086', '.model small', '.code', 'MAIN PROC', '    SHL AX, 4',
        '    RET', 'MAIN ENDP', 'END MAIN'
    )
    'BADOPS.ASM' = @(
        '.8086', '.model small', '.code', 'MAIN PROC',
        '    PUSH 1234h', '    POPA', '    IMUL AX, BX, 5',
        '    ENTER 0, 0', '    LEAVE', '    BOUND AX, [BX]',
        '    INSB', '    OUTSB', '    MOVZX AX, BL', '    MOVSX AX, BL',
        '    MOV EAX, EBX', '    SETZ AL', '    MOV AX, FS',
        '    RET', 'MAIN ENDP', 'END MAIN'
    )
}
foreach ($name in $invalidSources.Keys) {
    [IO.File]::WriteAllLines(
        (Join-Path $checkDirectory $name),
        [string[]]$invalidSources[$name],
        [Text.Encoding]::ASCII
    )
}
$lintOutput = & (Join-Path $PSHOME 'powershell.exe') -NoProfile `
    -ExecutionPolicy Bypass -File $lintPath -SourceRoot $checkDirectory 2>&1
if ($LASTEXITCODE -eq 0) {
    throw 'LINT8086.PS1 failed to detect the throwaway forbidden-instruction cases.'
}
$lintText = $lintOutput -join "`n"
foreach ($required in @('PUSH immediate', 'IMUL immediate', 'SHL immediate count', 'PUSHA', 'POPA', 'MOVZX', 'MOVSX', 'ENTER', 'LEAVE', 'BOUND', 'INSB', 'OUTSB', '32-bit register', 'SETZ', 'FS')) {
    if ($lintText -notmatch [regex]::Escape($required)) {
        throw "LINT8086.PS1 did not flag expected forbidden case: $required."
    }
}
Write-Output 'PASS: LINT8086.PS1 flags the throwaway forbidden-instruction cases.'

foreach ($input in $testInputs) {
    foreach ($extension in @('.OUT', '.ERR')) {
        Remove-Item (Join-Path $root ("TOOLS\" + $input.BaseName + $extension)) `
            -Force -ErrorAction SilentlyContinue
    }
}
Remove-Item (Join-Path $root 'TOOLS\STAGE0.LOG') -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $root 'TOOLS\BUILD.ERR') -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path $root 'TOOLS\BUILD.OUT') -Force -ErrorAction SilentlyContinue
Remove-Item $stdout, $stderr -Force -ErrorAction SilentlyContinue

$arguments = '-conf TOOLS\HEADLESS.CONF'
$process = Start-Process -FilePath $dosbox `
    -ArgumentList $arguments `
    -WorkingDirectory $root `
    -PassThru `
    -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr

Write-Output "DOSBox arguments: $arguments"
$timedOut = $false
try {
    Wait-Process -Id $process.Id -Timeout 30 -ErrorAction Stop
}
catch {
    $timedOut = $true
}

if ($timedOut) {
    $process.Refresh()
    if (-not $process.HasExited) {
        $process.Kill()
        $process.WaitForExit()
        throw "DOSBox exceeded the 30-second timeout and was terminated (PID $($process.Id))."
    }
}

$markerPath = Join-Path $root 'TOOLS\STAGE0.LOG'
if (-not (Test-Path $markerPath)) {
    throw 'DOSBox did not create TOOLS\STAGE0.LOG.'
}
$buildErrorPath = Join-Path $root 'TOOLS\BUILD.ERR'
if (Test-Path $buildErrorPath) {
    Get-Content (Join-Path $root 'TOOLS\BUILD.OUT')
    throw 'TASM or TLINK failed; see TOOLS\BUILD.OUT.'
}
$markers = [IO.File]::ReadAllLines($markerPath)
if (($markers -join ',') -ne 'START,END') {
    throw "Unexpected Stage 0 markers: $($markers -join ', ')."
}

$exitCodes = @{}
foreach ($input in $testInputs) {
    $actualPath = Join-Path $root ("TOOLS\" + $input.BaseName + '.OUT')
    $expectedPath = Join-Path $input.DirectoryName ($input.BaseName + '.EXP')
    $errorPath = Join-Path $root ("TOOLS\" + $input.BaseName + '.ERR')
    if (-not (Test-Path $actualPath)) {
        throw "Runner did not produce output for $($input.Name)."
    }
    if (-not (Test-Path $errorPath)) {
        throw "Runner did not capture an exit code for $($input.Name)."
    }
    if ([IO.File]::ReadAllText($errorPath).Trim() -eq 'CASE_FAILED') {
        throw "No executable was available for $($input.Name)."
    }

    $actual = [IO.File]::ReadAllBytes($actualPath)
    $expected = [IO.File]::ReadAllBytes($expectedPath)
    if (-not [Linq.Enumerable]::SequenceEqual([byte[]]$actual, [byte[]]$expected)) {
        throw "Output mismatch: $actualPath differs from $expectedPath."
    }
    $exitCode = [IO.File]::ReadAllText($errorPath).Trim()
    if ($exitCode -notmatch '^\d+$') {
        throw "Invalid captured exit code for $($input.Name): '$exitCode'."
    }
    $exitCodes[$input.BaseName] = $exitCode
    Write-Output "PASS: $actualPath matches $expectedPath; exit code $exitCode captured."
}

foreach ($name in @('BADPUSHA')) {
    $resultPath = Join-Path $checkDirectory ($name + '.RES')
    if (-not (Test-Path $resultPath) -or
        [IO.File]::ReadAllText($resultPath).Trim() -ne 'REJECTED') {
        throw "TASM did not reject the 8086-incompatible instruction in $name.ASM."
    }
    Write-Output "PASS: .8086 rejects $name.ASM."
}
$shiftResult = [IO.File]::ReadAllText((Join-Path $checkDirectory 'BADSHIFT.RES')).Trim()
if ($shiftResult -ne 'ACCEPTED') {
    throw 'TASM rejected SHL AX,4; inspect BADSHIFT.OUT and BADSHIFT.LST.'
}
$shiftListing = @(Get-Content (Join-Path $checkDirectory 'BADSHIFT.LST') |
    Where-Object { $_ -match 'SHL\s+AX\s*,\s*4' })
if ($shiftListing.Count -eq 0) {
    throw 'TASM listing did not show the SHL AX,4 instruction.'
}
$allShiftListingLines = Get-Content (Join-Path $checkDirectory 'BADSHIFT.LST')
$shiftListingIndex = [Array]::IndexOf($allShiftListingLines, $shiftListing[0])
$shiftContext = @($allShiftListingLines[$shiftListingIndex])
for ($offset = 1; $offset -le 2 -and $shiftListingIndex + $offset -lt $allShiftListingLines.Count; $offset++) {
    $shiftContext += $allShiftListingLines[$shiftListingIndex + $offset]
}
Write-Output "TASM SHL listing: $($shiftContext -join ' | ')"
if ($shiftListing[0] -match 'C1\s*E0\s*04|C1E004') {
    throw 'TASM emitted the 80186+ immediate-shift opcode for SHL AX,4.'
}
$shiftCount = [regex]::Matches($shiftListing[0], 'D1\s+E0').Count
if ($shiftListing[0] -match 'D1\+' -and
    $shiftContext.Count -gt 1 -and
    $shiftContext[1] -match '^\s*\d+\s+E0\s*$') {
    $shiftCount++
}
if ($shiftCount -ne 4) {
    throw 'Could not establish that TASM expanded SHL AX,4 into 8086-valid count-1 shifts.'
}
Write-Output 'PASS: TASM accepts the source syntax but emits four 8086-valid D1 E0 (SHL AX,1) instructions.'

$badOpsOutput = [IO.File]::ReadAllText((Join-Path $checkDirectory 'BADOPS.OUT'))
$badOpsSource = [IO.File]::ReadAllLines((Join-Path $checkDirectory 'BADOPS.ASM'))
$rejectedLines = @{}
foreach ($match in [regex]::Matches($badOpsOutput, '\*\*Error\*\*\s+BADOPS\.ASM\((\d+)\)')) {
    $rejectedLines[[int]$match.Groups[1].Value] = $true
}
for ($lineIndex = 0; $lineIndex -lt $badOpsSource.Count; $lineIndex++) {
    $instruction = $badOpsSource[$lineIndex].Trim()
    if ($instruction -match '^(PUSH|POPA|IMUL|ENTER|LEAVE|BOUND|INSB|OUTSB|MOVZX|MOVSX|MOV|SETZ)\b') {
        $disposition = if ($rejectedLines.ContainsKey($lineIndex + 1)) { 'rejects' } else { 'accepts silently' }
        Write-Output "TASM $disposition line $($lineIndex + 1): $instruction"
    }
}

if ($exitCodes['HELLO'] -ne '2') {
    throw "Expected HELLO exit code 2, got '$($exitCodes['HELLO'])'."
}
if ($exitCodes['READKEY'] -ne '0') {
    throw "Expected READKEY exit code 0, got '$($exitCodes['READKEY'])'."
}
$expectedSwitchExitCodes = @{
    'SW03' = '1'
    'SW06' = '0'
    'SW07' = '0'
}
foreach ($name in $expectedSwitchExitCodes.Keys) {
    if ($exitCodes[$name] -ne $expectedSwitchExitCodes[$name]) {
        throw "Expected $name exit code $($expectedSwitchExitCodes[$name]), got '$($exitCodes[$name])'."
    }
}

Write-Output '--- DOSBox stdout ---'
Get-Content $stdout
Write-Output '--- DOSBox stderr ---'
Get-Content $stderr
Remove-Item $checkDirectory -Recurse -Force
Remove-Item $caseScriptPath -Force
Write-Output 'Stage 0 headless proof passed.'
