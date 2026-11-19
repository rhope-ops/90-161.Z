@{
  RootModule        = 'PnP.PowerShell.psm1'
  ModuleVersion     = '1.12.0'
  GUID              = '0b0430ce-d799-4f3b-a565-f0dca1f31e17'
  Description       = 'Fake PnP.PowerShell for the 90-161.Z cloud tests (tests/ps/Test-T20.ps1: T20 and T19). Not the real module.'
  FunctionsToExport = @('Connect-PnPOnline', 'Disconnect-PnPOnline', 'Get-PnPContext', 'Get-PnPList', 'Invoke-PnPSPRestMethod', 'New-FakeSite', 'Add-FakeList',
    'Get-PnPField', 'Add-PnPFieldFromXml', 'Get-PnPListItem', 'Set-PnPListItem')
}
