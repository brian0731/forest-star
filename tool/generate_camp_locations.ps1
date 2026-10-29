$ErrorActionPreference = 'Stop'
$taskKey = [Environment]::GetEnvironmentVariable('APIXGO_IMAGE_API_KEY', 'User')
if ([string]::IsNullOrWhiteSpace($taskKey)) { throw 'APIXGO_IMAGE_API_KEY is not set.' }
$headers = @{ Authorization = "Bearer $taskKey" }
$output = Join-Path $PSScriptRoot '..\output\imagegen'
New-Item -ItemType Directory -Force -Path $output | Out-Null
$common = 'Use case: illustration-story. Asset: isolated mobile game location sprite. Cute original cozy forest adventure, polished hand-painted storybook game illustration, bright colors, soft lighting, slight elevated isometric perspective. Entire object visible, centered, with small margins. Isolated on a completely flat pure white background. No text, letters, logo, watermark, frame, UI, or surrounding scene.'
$jobs = @(
    @{ name = 'camp-pinball-v1.png'; subject = 'A whimsical pink and mint wooden pinball pavilion with a glass marble dome, a small pinball pegboard, and a tiny friendly bunny beside it.' },
    @{ name = 'camp-companions-v1.png'; subject = 'A cozy green-roofed little woodland cottage decorated with a paw print, with two adorable tiny animal companions outside the door.' },
    @{ name = 'camp-guard-v1.png'; subject = 'A charming wooden forest gate with a leaf shield and little watchtowers, with a tiny brave animal guard standing beside it.' }
)
foreach ($job in $jobs) {
    $path = Join-Path $output $job.name
    if (Test-Path -LiteralPath $path) { throw "Output already exists: $path" }
    $body = @{ model = 'gpt-image-2.5-flare'; prompt = "$common $($job.subject)"; n = 1; size = '1024x1024'; quality = 'high'; response_format = 'b64_json' } | ConvertTo-Json
    Write-Output "Generating $($job.name)..."
    $response = Invoke-RestMethod -Uri 'https://img.apixgo.com/v1/images/generations' -Method Post -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 180
    if ($response.data[0].b64_json) {
        [IO.File]::WriteAllBytes($path, [Convert]::FromBase64String($response.data[0].b64_json))
    } elseif ($response.data[0].url) {
        Invoke-WebRequest -Uri $response.data[0].url -OutFile $path
    } else { throw "No image returned for $($job.name)." }
    Write-Output "Saved $path"
}
Remove-Variable taskKey
