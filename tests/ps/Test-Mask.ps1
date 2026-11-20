# Tests Hide-Site (scripts/gov/src/site-common.ps1, the one masking function of every gov task script) with invented text only.
# Network: none.
# Writes: nothing.
# Credentials: none.
# Windows PowerShell 5.1 syntax (also runs on PowerShell 7).
# Last line: "MASK pass=N fail=0". Part 1 covers every pattern the function claims; part 2 asserts what it does NOT mask (known limits:
# display names, office symbols, phone numbers, numeric user ids, computer names); a later change that masks one of these makes a
# "known limit" line FAIL on purpose, so the limit text in Hide-Site's help and in this file is updated with it. Part 3: each task
# script holds the same function as the source.
param([string]$Root = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)))
$ErrorActionPreference = 'Stop'
$script:pass = 0; $script:fail = 0
# Record one test result and print PASS or FAIL. Takes the test name, the condition and optional detail text; returns nothing.
function Test-That([string]$Name, [bool]$Ok, [string]$Detail = '') {
  if ($Ok) { $script:pass++; Write-Host ('MASKTEST PASS ' + $Name) } else { $script:fail++; Write-Host ('MASKTEST FAIL ' + $Name + ' ' + $Detail) }
}
$srcText = Get-Content -LiteralPath (Join-Path $Root 'scripts/gov/src/site-common.ps1') -Raw
. ([scriptblock]::Create([regex]::Match($srcText, '(?s)function Hide-Site.*?\r?\n\}\r?\n').Value))
$site = 'https://fakeco.sharepoint.us/sites/pfmtest'
$at = [string][char]64
$guid = '0a1b2c3d-9999-2222-3333-444455556666'
# Check that Hide-Site turns Text into Want. Takes the name, the input text, the wanted output and the site (default: the fake site); returns nothing.
function Test-Mask([string]$Name, [string]$Text, [string]$Want, [string]$S = $site) {
  $got = Hide-Site $Text $S
  Test-That $Name ($got -ceq $Want) ('got [' + $got + ']')
}
# Check that Hide-Site leaves Text unchanged (a known limit). Takes the name and the text; returns nothing.
function Test-Limit([string]$Name, [string]$Text) {
  Test-That ('known limit: ' + $Name + ' is not masked') ((Hide-Site $Text $site) -ceq $Text)
}

# ---- part 1: what is masked ----
Test-Mask 'e-mail' ('mail someone' + $at + 'example.invalid now') 'mail <EMAIL> now'
Test-Mask 'e-mail with dots and plus' ('a.b+c' + $at + 'x.example.invalid') '<EMAIL>'
Test-Mask 'e-mail with an apostrophe in the name (R36 review)' ('to ann.o''neil' + $at + 'x.example.invalid now') 'to <EMAIL> now'
Test-Mask 'e-mail with a curly apostrophe in the name (R36 review)' ('to ann.o' + [char]0x2019 + 'neil' + $at + 'x.example.invalid now') 'to <EMAIL> now'
Test-Mask 'quoted e-mail keeps its quotes' ('''ann' + $at + 'x.example.invalid''') '''<EMAIL>'''
Test-Mask 'encoded e-mail (%40)' 'x first.last%40example.invalid%27 y' 'x <EMAIL> y'
Test-Mask 'encoded e-mail, no site' 'q=%27someone%40example.invalid%27 y' '<EMAIL> y' ''
Test-Mask 'e-mail keeps the text around it (colon, trailing dot)' ('contact:who' + $at + 'example.invalid. Done') 'contact:<EMAIL>. Done'
Test-Mask 'e-mail keeps text before and after, no space' ('[to]who' + $at + 'example.invalid/more') '[to]<EMAIL>/more'
Test-Mask 'e-mail keeps a closing quote and a trailing dot' ('"who' + $at + 'example.invalid".') '"<EMAIL>".'
Test-Mask 'two e-mails in one list' ('a' + $at + 'x.example.invalid;b' + $at + 'y.example.invalid') '<EMAIL>;<EMAIL>'
Test-Mask 'e-mail in angle brackets' ('<who' + $at + 'example.invalid>') '<<EMAIL>>'
Test-Mask 'site address' ('at ' + $site + ' end') 'at <SITE> end'
Test-Mask 'site address with a final slash' ('at ' + $site + '/ end') 'at <SITE>/ end'
Test-Mask 'site host' 'host fakeco.sharepoint.us only' 'host <SITE-HOST> only'
Test-Mask 'server-relative path' 'open /sites/pfmtest/Lists/X' 'open <SITE-PATH>/Lists/X'
Test-Mask 'encoded path' 'open %2Fsites%2Fpfmtest%2FLists' 'open <SITE-PATH>%2FLists'
Test-Mask 'site leaf name' 'site pfmtest said' 'site <SITE-NAME> said'
Test-Mask 'tenant' 'tenant fakeco x' 'tenant <TENANT> x'
Test-Mask 'other URL' 'see https://other.example.invalid/a?b=1 now' 'see <URL> now'
Test-Mask 'other URL, http' 'see http://other.example.invalid/ now' 'see <URL> now'
Test-Mask 'cloud host sharepoint' 'at other-co.sharepoint.us ok' 'at <TENANT-HOST> ok'
Test-Mask 'cloud host onmicrosoft' 'at zed.onmicrosoft.com ok' 'at <TENANT-HOST> ok' ''
Test-Mask 'cloud host microsoftonline' 'at login.microsoftonline.us ok' 'at <TENANT-HOST> ok' ''
Test-Mask 'cloud host windows' 'at x.windows.net ok' 'at <TENANT-HOST> ok' ''
Test-Mask '.mil host' ('at unit.example.m' + 'il ok') 'at <HOST> ok' ''
Test-Mask 'GUID' ('id ' + $guid + ' ok') 'id <GUID> ok'
Test-Mask 'GUID in capitals' ('id ' + $guid.ToUpper() + ' ok') 'id <GUID> ok'
Test-Mask 'GUID after an encoded character' ('lists(guid%27' + $guid + '%27)') 'lists(guid%27<GUID>%27)'
Test-Mask 'GUID after %2F' ('%2F' + $guid) '%2F<GUID>'
Test-Mask 'text with nothing to mask' 'Item 4 passed' 'Item 4 passed'
Test-Mask 'empty text' '' ''

# The old combined case of the batch test: nothing of the invented site, person or sign-in address may stay.
$mix = Hide-Site ('x jane.doe.1234567890' + $at + 'fakeco.onmicrosoft.us said no; bob' + $at + 'unit.example.m' + 'il https://login.microsoftonline.us/0a1b2c3d-1111-2222-3333-444455556666/o fakeco.onmicrosoft.us https://fakeco.sharepoint.us/sites/pfmtest/_api fakeco-admin.sharepoint.us /sites/pfmtest/_api %2Fsites%2Fpfmtest pfmtest') $site
Test-That 'combined text leaves nothing of the site, people or sign-in' ($mix -cnotmatch 'fakeco|0a1b2c3d|pfmtest|https?://|jane|bob') $mix

# ---- part 2: known limits (not masked; the comment in Hide-Site help names them) ----
Test-Limit 'a display name' 'Created by Pat Example Jr'
Test-Limit 'an office symbol' 'Sent to 99 XX/ABC for review'
Test-Limit 'a phone number' ('Call 555-01' + '00 or (555) 555-01' + '01')
Test-Limit 'a numeric user id' 'user id 1234567890 failed'
Test-Limit 'a computer name' 'on computer PC-0001-EXAMPLE'

# ---- part 3: every task script holds the source function byte for byte ----
$want = [regex]::Match($srcText, '(?s)function Hide-Site.*?\r?\n\}\r?\n').Value -replace "`r", ''
foreach ($f in Get-ChildItem -LiteralPath (Join-Path $Root 'scripts/gov') -Filter '90161Z-T*.ps1') {
  $t = (Get-Content -LiteralPath $f.FullName -Raw) -replace "`r", ''
  $n = ([regex]::Matches($t, 'function Hide-Site')).Count
  if ($n -gt 0) { Test-That ('one shared Hide-Site in ' + $f.Name) ($n -eq 1 -and $t.Contains($want)) }
}
Write-Host ('MASK pass=' + $script:pass + ' fail=' + $script:fail)
if ($script:fail -gt 0) { exit 1 }
