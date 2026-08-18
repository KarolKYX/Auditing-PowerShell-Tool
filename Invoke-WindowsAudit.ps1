function Get-SystemSecurityReport {
    [CmdletBinding()]
    param (
        [string]$Path = "Security_Report.html",
        [switch]$OpenInBrowser
    )

    # 1. Visual Style (CSS)
    $styleCSS = @"
<style>
    body {
        font-family: 'Segoe UI', Arial, sans-serif;
        background-color: #f4f6f9;
        color: #333333;
        margin: 40px;
    }
    h1 {
        color: #1a252f;
        border-bottom: 3px solid #3498db;
        padding-bottom: 10px;
    }
    h2 {
        color: #2c3e50;
        margin-top: 30px;
    }
    .info-bar {
        background-color: #e8f4f8;
        border-left: 4px solid #3498db;
        padding: 10px 15px;
        margin-bottom: 25px;
        font-size: 0.9em;
    }
    table {
        border-collapse: collapse;
        width: 100%;
        margin-bottom: 30px;
        background-color: #ffffff;
        box-shadow: 0 2px 5px rgba(0,0,0,0.05);
        border-radius: 6px;
        overflow: hidden;
    }
    th {
        background-color: #3498db;
        color: #ffffff;
        text-align: left;
        padding: 12px 15px;
        font-weight: 600;
    }
    td {
        padding: 10px 15px;
        border-bottom: 1px solid #eeeeee;
    }
    tr:nth-child(even) {
        background-color: #f8f9fa;
    }
    tr:hover {
        background-color: #f1f5f9;
    }
</style>
"@

    # 2. Gathering Windows Firewall profile states
    $firewallProfiles = Get-NetFirewallProfile 
    $firewallReport = foreach ($profile in $firewallProfiles) { 
        [PSCustomObject]@{ 
            ProfileName    = $profile.Name
            Enabled        = $profile.Enabled
            InboundAction  = $profile.DefaultInboundAction
            OutboundAction = $profile.DefaultOutboundAction
            LogFileName    = $profile.LogFileName
        }
    }

    # 3. Gathering active ports, network connections, and owning processes
    $tcpConnections = Get-NetTCPConnection -State Listen, Established | Sort-Object OwningProcess

    $portsReport = foreach ($conn in $tcpConnections) {
        $process = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue

        [PSCustomObject]@{
            LocalAddress  = $conn.LocalAddress
            LocalPort     = $conn.LocalPort
            RemoteAddress = $conn.RemoteAddress
            RemotePort    = $conn.RemotePort
            State         = $conn.State
            ProcessID     = $conn.OwningProcess
            ProcessName   = if ($process) { $process.ProcessName } else { "System/Unknown" }
        }
    }

    # 4. Generating HTML table fragments
    $htmlFirewall = $firewallReport | ConvertTo-Html -Fragment -PreContent "<h2>1. Windows Firewall Status</h2>"
    $htmlPorts    = $portsReport    | ConvertTo-Html -Fragment -PreContent "<h2>2. Active Ports & Services (Listen / Established)</h2>"

    # 5. Assembling HTML document body
    $generationDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $body = @"
<h1>System Security Audit Report</h1>
<div class="info-bar">
    <strong>Generated:</strong> $generationDate | 
    <strong>Hostname:</strong> $env:COMPUTERNAME | 
    <strong>Audited By:</strong> $env:USERNAME
</div>

$htmlFirewall
$htmlPorts
"@

    # 6. Combining components and exporting to HTML file
    ConvertTo-Html -Head $styleCSS -Body $body -Title "System Security Report" | 
        Set-Content -Path $Path -Encoding UTF8

    Write-Host "[+] Security report successfully saved to: $Path" -ForegroundColor Green

    # 7. Open report in default browser if switch is provided
    if ($OpenInBrowser) {
        Invoke-Item $Path
    }
}

Get-SystemSecurityReport -OpenInBrowser