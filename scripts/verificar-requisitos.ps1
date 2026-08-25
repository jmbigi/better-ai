[CmdletBinding()]
param(
    [string]$Root = (Get-Location).Path
)

$validator = Join-Path $Root "scripts/doc_validator.py"
if (-not (Test-Path -LiteralPath $validator -PathType Leaf)) {
    throw "No existe el validador: $validator"
}

$python = Get-Command py -ErrorAction SilentlyContinue
if ($null -eq $python) {
    $python = Get-Command python -ErrorAction SilentlyContinue
}
if ($null -eq $python) {
    throw "Se requiere Python 3 (comando 'py' o 'python')"
}

& $python.Source $validator --root $Root
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
