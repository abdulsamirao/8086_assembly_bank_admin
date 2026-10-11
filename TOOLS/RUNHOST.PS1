$ErrorActionPreference = 'Stop'

$root = 'C:\practical\CALD_PROJECT'
$dosbox = 'C:\Users\abdul\AppData\Local\Programs\DOSBox Staging\dosbox.exe'
$stdout = Join-Path $root 'TOOLS\HEADLESS.OUT'
$stderr = Join-Path $root 'TOOLS\HEADLESS.ERR'
$outputs = @(
    'TOOLS\STAGE0.LOG',
    'TOOLS\BUILD.ERR',
    'TOOLS\HELLO.OUT',
    'TOOLS\HELLO.ERR',
    'TOOLS\READKEY.OUT',
    'TOOLS\READKEY.ERR'
)

foreach ($relativePath in $outputs) {
    Remove-Item (Join-Path $root $relativePath) -Force -ErrorAction SilentlyContinue
}
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
$markers = [IO.File]::ReadAllLines($markerPath)
if (($markers -join ',') -ne 'START,END') {
    throw "Unexpected Stage 0 markers: $($markers -join ', ')."
}
if (Test-Path (Join-Path $root 'TOOLS\BUILD.ERR')) {
    throw 'TASM or TLINK failed; see TOOLS\BUILD.ERR.'
}

$comparisons = @(
    @('TOOLS\HELLO.OUT', 'TESTS\HELLO.EXP'),
    @('TOOLS\READKEY.OUT', 'TESTS\READKEY.EXP')
)
foreach ($pair in $comparisons) {
    $actual = [IO.File]::ReadAllBytes((Join-Path $root $pair[0]))
    $expected = [IO.File]::ReadAllBytes((Join-Path $root $pair[1]))
    if (-not [Linq.Enumerable]::SequenceEqual([byte[]]$actual, [byte[]]$expected)) {
        throw "Output mismatch: $($pair[0]) differs from $($pair[1])."
    }
    Write-Output "PASS: $($pair[0]) matches $($pair[1])."
}

$helloExit = [IO.File]::ReadAllText((Join-Path $root 'TOOLS\HELLO.ERR')).Trim()
$readKeyExit = [IO.File]::ReadAllText((Join-Path $root 'TOOLS\READKEY.ERR')).Trim()
if ($helloExit -ne '2') {
    throw "Expected HELLO exit code 2, got '$helloExit'."
}
if ($readKeyExit -ne '0') {
    throw "Expected READKEY exit code 0, got '$readKeyExit'."
}
Write-Output 'PASS: HELLO exit code 2 captured in HELLO.ERR.'
Write-Output 'PASS: READKEY exit code 0 captured in READKEY.ERR.'

Write-Output '--- DOSBox stdout ---'
Get-Content $stdout
Write-Output '--- DOSBox stderr ---'
Get-Content $stderr
Write-Output 'Stage 0 headless proof passed.'
