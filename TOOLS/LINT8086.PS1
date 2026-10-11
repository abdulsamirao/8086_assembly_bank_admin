param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot
)

$ErrorActionPreference = 'Stop'
$files = @(Get-ChildItem -Path $SourceRoot -Recurse -File |
    Where-Object { $_.Extension -in @('.ASM', '.INC') })
$issues = [Collections.Generic.List[string]]::new()
$forbiddenMnemonics = '^(PUSHA|POPA|ENTER|LEAVE|BOUND|INS|INSB|INSW|OUTS|OUTSB|OUTSW|MOVZX|MOVSX|FS|GS)$'
$setCondition = '^SET(O|NO|B|NB|C|NC|AE|E|Z|NE|NZ|BE|A|NA|NBE|S|NS|P|PE|NP|PO|L|GE|LE|G)$'
$conditionalJump = '^(JO|JNO|JB|JNB|JC|JNC|JNAE|JAE|JE|JZ|JNE|JNZ|JBE|JA|JNA|JNBE|JS|JNS|JP|JPE|JNP|JPO|JL|JGE|JLE|JG)$'
$register32 = '\b(EAX|EBX|ECX|EDX|ESI|EDI|ESP|EBP|EIP)\b'
$literal = '^(?:[+-]?\d+|[0-9A-F]+H|0X[0-9A-F]+|[01]+B)$'

function Test-ImmediateOperand {
    param([string]$Operand)
    $value = $Operand.Trim()
    if ($value -match $literal) { return $true }
    if ($value -match "^(OFFSET|SEG|LOW|HIGH)\b") { return $true }
    if ($value.StartsWith("'") -or $value.StartsWith('"')) { return $true }
    return $false
}

function Convert-IntegerLiteral {
    param([string]$Literal)
    $value = $Literal.Trim().ToUpperInvariant()
    if ($value.EndsWith('H')) { return [Convert]::ToInt32($value.TrimEnd('H'), 16) }
    if ($value.StartsWith('0X')) { return [Convert]::ToInt32($value.Substring(2), 16) }
    if ($value.EndsWith('B')) { return [Convert]::ToInt32($value.TrimEnd('B'), 2) }
    return [Convert]::ToInt32($value, 10)
}

foreach ($file in $files) {
    $lines = [IO.File]::ReadAllLines($file.FullName)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '.8086') {
        $issues.Add("$($file.Name):1: source must begin with .8086")
    }

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $code = ($lines[$index] -split ';', 2)[0]
        $code = $code -replace '^\s*[A-Za-z_?$@][A-Za-z0-9_?$@]*:\s*', ''
        $match = [regex]::Match($code, '^\s*(?<mnemonic>[A-Za-z][A-Za-z0-9]*)\b(?<operands>.*)$')
        if (-not $match.Success) { continue }

        $mnemonic = $match.Groups['mnemonic'].Value.ToUpperInvariant()
        $operandsText = $match.Groups['operands'].Value.Trim()
        $where = "$($file.Name):$($index + 1)"

        if ($mnemonic -match $forbiddenMnemonics -or $mnemonic -match $setCondition) {
            $issues.Add("${where}: forbidden 8086 opcode/register $mnemonic")
        }
        if ($code -match $register32) {
            $issues.Add("${where}: 32-bit register used")
        }
        if ($code -match '\b(FS|GS)\b') {
            $issues.Add("${where}: forbidden FS/GS segment register or override")
        }
        if ($mnemonic -match $conditionalJump -and $operandsText -match '^\s*NEAR\b') {
            $issues.Add("${where}: near conditional jump is not available on 8086")
        }

        $operands = @($operandsText -split ',')
        if ($mnemonic -match '^(ROL|ROR|RCL|RCR|SHL|SAL|SHR|SAR)$' -and $operands.Count -ge 2) {
            $countText = $operands[1].Trim()
            if ($countText -match $literal) {
                if ((Convert-IntegerLiteral $countText) -ne 1) {
                    $issues.Add("${where}: $mnemonic immediate count must be 1")
                }
            }
        }
        if ($mnemonic -eq 'PUSH' -and (Test-ImmediateOperand $operandsText)) {
            $issues.Add("${where}: PUSH immediate is not available on 8086")
        }
        if ($mnemonic -eq 'IMUL') {
            foreach ($operand in $operands) {
                if (Test-ImmediateOperand $operand) {
                    $issues.Add("${where}: IMUL immediate form is not available on 8086")
                    break
                }
            }
        }
    }
}

if ($issues.Count -gt 0) {
    $issues | ForEach-Object { Write-Output $_ }
    exit 1
}

Write-Output "8086 lint passed: $($files.Count) ASM/INC sources checked."
