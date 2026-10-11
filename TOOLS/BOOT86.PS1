param(
    [Parameter(Mandatory = $true)]
    [string]$ToolDirectory
)

$ErrorActionPreference = 'Stop'

$tasmPath = Join-Path $ToolDirectory 'TASM.EXE'
$tlinkPath = Join-Path $ToolDirectory 'TLINK.EXE'
if ((Test-Path $tasmPath -PathType Leaf) -and
    (Test-Path $tlinkPath -PathType Leaf)) {
    Write-Output 'PASS: TASM.EXE and TLINK.EXE already exist; bootstrap skipped.'
    return
}

$extensionRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
$extensions = @(Get-ChildItem $extensionRoot -Directory `
    -Filter 'xsro.masm-tasm-*' -ErrorAction SilentlyContinue)
$bundles = foreach ($extension in $extensions) {
    if ($extension.Name -match '^xsro\.masm-tasm-(\d+(?:\.\d+){1,3})$') {
        $bundlePath = Join-Path $extension.FullName 'resources\TASM.jsdos'
        if (Test-Path $bundlePath -PathType Leaf) {
            [pscustomobject]@{
                Version = [version]$Matches[1]
                Path = $bundlePath
            }
        }
    }
}
$bundle = $bundles | Sort-Object Version -Descending | Select-Object -First 1
if ($null -eq $bundle) {
    throw "The MASM/TASM VS Code extension was not found under '$extensionRoot'. Install the MASM/TASM extension and rerun."
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($bundle.Path)
try {
    New-Item -ItemType Directory -Path $ToolDirectory -Force | Out-Null
    foreach ($fileName in @('TASM.EXE', 'TLINK.EXE', 'RTM.EXE', 'DPMI16BI.OVL')) {
        $entry = $archive.GetEntry("tasm/$fileName")
        if ($null -eq $entry) {
            throw "The MASM/TASM extension bundle is missing tasm/$fileName."
        }

        $inputStream = $entry.Open()
        try {
            $outputStream = [IO.File]::Open(
                (Join-Path $ToolDirectory $fileName),
                [IO.FileMode]::Create,
                [IO.FileAccess]::Write,
                [IO.FileShare]::None
            )
            try {
                $inputStream.CopyTo($outputStream)
            }
            finally {
                $outputStream.Dispose()
            }
        }
        finally {
            $inputStream.Dispose()
        }
    }
}
finally {
    $archive.Dispose()
}

Write-Output "PASS: extracted TASM/TLINK and DOS runtime files from $($bundle.Path)."
