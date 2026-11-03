$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$destination = 'C:\Geography\R\dissertation_LakeEnsemblR\LER4_release_20261103'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
$archive = Join-Path $destination 'LER4_workflow_complete_20261103.zip'
$uri = 'https://raw.githubusercontent.com/yhy3158004870/LakeEnsemblR/codex/research4-20261103/research_releases/20261103_four_models/LER4_workflow_complete_20261103.zip'
Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $archive
$expected = '3372a2c77d1f021078df573cc5321538fa2a924dc1722befa8cdc49360144c2f'
if ((Get-FileHash -Algorithm SHA256 -LiteralPath $archive).Hash.ToLowerInvariant() -ne $expected) {
    throw 'Downloaded ZIP checksum differs. Nothing extracted.'
}
Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force
Write-Host 'WORKFLOW_DOWNLOADED_AND_SHA256_VERIFIED'
Write-Host $destination
Write-Host 'Open Prepare_and_START_remaining67_12_COMPLETE_20261103.ipynb in Jupyter.'
