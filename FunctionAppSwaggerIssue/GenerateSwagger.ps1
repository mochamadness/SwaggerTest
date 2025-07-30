param(
    [string]$OutputPath = "./bin/Debug/net9.0/",
    [string]$Port = "7165",
    [string]$SwaggerOutputPath = "./swagger.json"
)

if (-not (Test-Path $OutputPath)) {
    Write-Error "Output path $OutputPath does not exist."
    exit 1
}

$exePath = Get-ChildItem -Path $OutputPath -Filter "*.dll" | Where-Object { $_.Name -notlike "*ref*" } | Select-Object -First 1

if (-not $exePath) {
    Write-Error "No DLL found in $OutputPath"
    exit 1
}

Write-Host "Starting function host: dotnet $($exePath.FullName)"

# Start the function host using dotnet
$process = Start-Process -FilePath "dotnet" -ArgumentList "$($exePath.FullName) --port $Port" -PassThru -WindowStyle Hidden

try {
    # Wait for startup
    Write-Host "Waiting for function host to start..."
    Start-Sleep -Seconds 15
    
    # Test if the host is responding
    $response = $null
    for ($i = 0; $i -lt 10; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:$Port/api/swagger.json" -TimeoutSec 5
            break
        } catch {
            Write-Host "Attempt $($i+1): Function host not ready yet..."
            Start-Sleep -Seconds 3
        }
    }
    
    if ($response) {
        $response.Content | Out-File -FilePath $SwaggerOutputPath -Encoding UTF8
        Write-Host "swagger.json generated successfully at: $SwaggerOutputPath"
    } else {
        Write-Error "Failed to retrieve swagger.json from function host"
        exit 1
    }
} finally {
    # Clean up
    if ($process -and !$process.HasExited) {
        Stop-Process -Id $process.Id -Force
        Write-Host "Function host stopped"
    }
}