<#
.SYNOPSIS
  90-161.Z Task 21 probe r14, module "look": the parts Form (a header on the list form) and View (a list view with a
  button that starts the button flow "90161Z T21 Probe Button r6" of the solution "90-161.Z flows"). The part Look runs
  both.
.DESCRIPTION
  Loaded by 90161Z-T21-probe-r14.ps1 (dot-sourced from the same folder); it does nothing when it is run alone.
  Inputs: the values the main file sets ($ListTitle, $ListFolder, $ViewTitle, $HeaderText) and the helpers of the module
  "common"; View takes the button flow's ID from the button-flow-id block below, which scripts/build_flow_solution.py
  writes at build time (the flow's workflow ID in the solution, the same on every build; R34: no export file). Outputs:
  result lines through Add-Item and Add-Test (FORM, VIEW).
  R29a finding 6: the round skipped the look at the form because one step held both tests and the view failed. With Form
  and View as separate parts, the round can run the look at the form after Form alone.
  Network: the one SharePoint site of the main file, through the PnP.PowerShell connection (CSOM, then REST).
  Writes: Form: the form formatting (ClientFormCustomFormatter) of the probe list's content type. View: the view
          "ProbeButton" on the probe list and its formatting (CustomFormatter). Nothing on this computer.
  Credentials: none of its own (the main file signs in).
  Run: not alone; powershell.exe -File 90161Z-T21-probe-r14.ps1 -Part Form, View or Look loads it.
#>

# >>> button-flow-id: generated from flow/solution/defs/90161Z-T21-probe-button-r6.json by scripts/build_flow_solution.py (do not edit)
$ButtonFlowId = 'ce93ba66-4985-5431-bec3-5f371af52372'
# <<< button-flow-id

<#
.SYNOPSIS
  Sets a formatting JSON on a content type (form header) or a view. Easy path first: the CSOM property; then the REST
  merge.
.PARAMETER Kind
  'form' (content type) or 'view'.
.PARAMETER Json
  The formatting JSON text.
.PARAMETER ListId
  The probe list's Id.
.PARAMETER TargetId
  The content type Id (form) or the view Id (view).
.OUTPUTS
  System.String. 'csom', 'rest' or 'none'; the last error text is kept in $script:fmtError.
#>
function Send-Formatter([string]$Kind, [string]$Json, [string]$ListId, [string]$TargetId) {
  $script:fmtError = ''
  try {
    $ctx = Get-PnPContext
    $list = $ctx.Web.Lists.GetById([guid]$ListId)
    if ($Kind -eq 'form') { $t = $list.ContentTypes.GetById($TargetId); $t.ClientFormCustomFormatter = $Json; $t.Update($false) }
    else { $t = $list.Views.GetById([guid]$TargetId); $t.CustomFormatter = $Json; $t.Update() }
    $ctx.ExecuteQuery()
    return 'csom'
  } catch { $script:fmtError = [string]$_.Exception.Message }
  try {
    $lbase = "_api/web/lists(guid'" + $ListId + "')"
    if ($Kind -eq 'form') {
      $body = @{ __metadata = @{ type = 'SP.ContentType' }; ClientFormCustomFormatter = $Json } | ConvertTo-Json -Depth 5 -Compress
      $null = Invoke-Rest 'Merge' ($lbase + "/contenttypes('" + $TargetId + "')") $body
    } else {
      $body = @{ __metadata = @{ type = 'SP.View' }; CustomFormatter = $Json } | ConvertTo-Json -Depth 5 -Compress
      $null = Invoke-Rest 'Merge' ($lbase + "/views(guid'" + $TargetId + "')") $body
    }
    return 'rest'
  } catch { $script:fmtError = [string]$_.Exception.Message }
  return 'none'
}

# Finds the probe list or stops the part (Form and View need it).
function Get-ProbeListOrStop {
  Write-Now 'Looking for the probe list'
  $lst = Find-ByFolder $ListFolder
  if (-not $lst) { throw 'LIST not found: run -Part Make first.' }
  return $lst
}

<#
.SYNOPSIS
  The part Form (a): the header of the list form (the form formatting of the content type), read back from the content
  type. Adds the ITEM line l1-form and the test FORM.
#>
function Invoke-FormPart {
  $lst = Get-ProbeListOrStop
  $lbase = "_api/web/lists(guid'" + $lst.Id + "')"
  $ctId = ''
  try { $cts = @(Get-RestValue ($lbase + '/contenttypes?$select=Id,Name')); if ($cts.Count) { $ctId = [string]$cts[0].Id.StringValue } } catch { $ctId = '' }
  $formPass = $false; $route = 'none'; $readBack = 'no'
  if (-not $ctId) { Add-Item 'l1-form' 'FAIL' 'no content type found on the list' }
  else {
    $hdr = [ordered]@{ headerJSONFormatter = [ordered]@{ elmType = 'div'; style = [ordered]@{ padding = '12px'; 'font-size' = '18px'; 'font-weight' = '600' }; txtContent = $HeaderText } }
    Write-Now 'Setting the header on the list form and reading it back'
    $route = Send-Formatter 'form' ($hdr | ConvertTo-Json -Depth 8 -Compress) ([string]$lst.Id) $ctId
    try {
      $raw = Invoke-Rest 'Get' ($lbase + "/contenttypes('" + $ctId + "')?" + '$select=ClientFormCustomFormatter') ''
      if ($raw.Contains($HeaderText)) { $readBack = 'yes' }
    } catch { $readBack = 'not read' }
    $formPass = ($readBack -eq 'yes')
    $why = $(if ($route -eq 'none') { '; ' + (Format-Detail $script:fmtError) } else { '' })
    Add-Item 'l1-form' $(if ($formPass) { 'PASS' } else { 'FAIL' }) ('header formatting set (route=' + $route + ') and read back from the content type=' + $readBack + $why)
  }
  $summary = 'a header on the list form (form formatting set by script)=' + $(if ($formPass) { 'PASS' } else { 'FAIL' }) + ' (route=' + $route + '; read back=' + $readBack + ')'
  Add-Test 'FORM' @($summary + '; what the form shows is left to your answers') $formPass
}

# The button flow's ID from the button-flow-id block (lower case), or '' when the block holds no ID.
function Get-ButtonFlowId {
  $bt = ([string]$ButtonFlowId).Trim()
  if ($bt -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') { return $bt.ToLowerInvariant() }
  return ''
}

<#
.SYNOPSIS
  Makes the view "ProbeButton" when it is missing and returns its Id ('' when it is not there after the create step).
.PARAMETER ListBase
  The REST address of the probe list (_api/web/lists(guid'...')).
.OUTPUTS
  System.Collections.Hashtable. Id (the view Id or '') and Made (1 when the view was made now, else 0).
#>
function Get-ButtonView([string]$ListBase) {
  $viewId = ''
  try { $vs = @(Get-RestValue ($ListBase + '/views?$select=Id,Title') | Where-Object { [string]$_.Title -eq $ViewTitle }); if ($vs.Count) { $viewId = [string]$vs[0].Id } } catch { $viewId = '' }
  $viewMade = 0
  if (-not $viewId) {
    Write-Now ('Making the view ' + $ViewTitle)
    $null = Add-PnPView -List $ListTitle -Title $ViewTitle -Fields @('Title', 'ProbeTest', 'ProbeResult') -ErrorAction Stop
    $viewMade++
    $vs = @(Get-RestValue ($ListBase + '/views?$select=Id,Title') | Where-Object { [string]$_.Title -eq $ViewTitle }); if ($vs.Count) { $viewId = [string]$vs[0].Id }
  }
  return @{ Id = $viewId; Made = $viewMade }
}

<#
.SYNOPSIS
  The part View (b): a view with a button that starts the button flow (customRowAction executeFlow with the ID of the
  flow "90161Z T21 Probe Button r6" from the button-flow-id block), read back from the view. Adds the ITEM line l2-view and
  the test VIEW.
#>
function Invoke-ViewPart {
  $lst = Get-ProbeListOrStop
  $lbase = "_api/web/lists(guid'" + $lst.Id + "')"
  $btnId = Get-ButtonFlowId
  if (-not $btnId) {
    Add-Item 'l2-view' 'FAIL' 'no button flow ID in the look module (its button-flow-id block is empty), so the view was not made'
    Add-Test 'VIEW' @('b a view formatted by script with a button that starts a flow=FAIL (flow ID known to the script=no; the build left no ID)') $false
    return
  }
  $view = Get-ButtonView $lbase
  $viewPass = $false; $vroute = 'none'; $vback = 'no'
  if (-not $view.Id) { Add-Item 'l2-view' 'FAIL' 'the view is not on the list after the create step' }
  else {
    $params = '{"id":"' + $btnId + '","headerText":"Run the test flow","runFlowButtonText":"Run"}'
    $fmt = [ordered]@{ '$schema' = 'https://developer.microsoft.com/json-schemas/sp/view-formatting.schema.json'
      rowFormatter = [ordered]@{ elmType = 'div'; style = [ordered]@{ display = 'flex'; 'align-items' = 'center'; padding = '4px' }
        children = @([ordered]@{ elmType = 'span'; style = [ordered]@{ flex = '1' }; txtContent = '[$Title]' },
          [ordered]@{ elmType = 'button'; txtContent = 'Run the test flow'; customRowAction = [ordered]@{ action = 'executeFlow'; actionParams = $params } }) } }
    Write-Now 'Setting the button on the view and reading it back'
    $vroute = Send-Formatter 'view' ($fmt | ConvertTo-Json -Depth 10 -Compress) ([string]$lst.Id) $view.Id
    try {
      $raw = Invoke-Rest 'Get' ($lbase + "/views(guid'" + $view.Id + "')?" + '$select=CustomFormatter') ''
      if ($raw.Contains('executeFlow') -and $raw.Contains($btnId)) { $vback = 'yes' }
    } catch { $vback = 'not read' }
    $viewPass = ($vback -eq 'yes')
    $why = $(if ($vroute -eq 'none') { '; ' + (Format-Detail $script:fmtError) } else { '' })
    Add-Item 'l2-view' $(if ($viewPass) { 'PASS' } else { 'FAIL' }) ('view made now=' + $view.Made + '; formatting set (route=' + $vroute + ') and read back from the view=' + $vback + $why)
  }
  $summary = 'b a view formatted by script with a button that starts a flow=' + $(if ($viewPass) { 'PASS' } else { 'FAIL' })
  Add-Test 'VIEW' @($summary + ' (route=' + $vroute + '; read back=' + $vback + '; flow ID known to the script=yes); whether the button runs is read by the Read part') $viewPass
}
