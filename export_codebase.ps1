# Function to check if directory should be excluded
function ShouldExcludeDirectory($path) {
    $excludeDirs = @(
        '.dart_tool',
        'build',
        '.idea',
        '.vscode',
        'ios',
        'linux',
        'macos',
        'windows',
        'web',
        '.gradle'
    )

    foreach ($dir in $excludeDirs) {
        if ($path -like "*\$dir\*") {
            return $true
        }
    }
    return $false
}

# Function to check if file should be included
function ShouldIncludeFile($filePath) {
    $includePatterns = @(
        "*.dart",
        "build.gradle",
        "settings.gradle",
        "gradle.properties",
        "gradle-wrapper.properties",
        "AndroidManifest.xml",
        "proguard-rules.pro",
        "*.properties",
        "google-services.json",
        "*.yaml"
    )

    foreach ($pattern in $includePatterns) {
        if ($filePath -like $pattern) {
            return $true
        }
    }
    return $false
}

# Function to get file content
function GetFileContent($filePath) {
    if (Test-Path $filePath) {
        try {
            $content = Get-Content $filePath -Raw -Encoding UTF8
            return $content
        }
        catch {
            Write-Warning "Could not read file: $filePath"
            return $null
        }
    }
    return $null
}

# Main script
$projectRoot = "C:\VSCode\fftcg_companion_app"  # Adjust this path to your project root
$outputFile = "codebase_export.json"
$codeFiles = @{}

# Get all files recursively
Get-ChildItem -Path $projectRoot -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Replace($projectRoot + "\", "")
    
    if (-not (ShouldExcludeDirectory $_.FullName) -and (ShouldIncludeFile $_.Name)) {
        $content = GetFileContent $_.FullName
        if ($content) {
            $codeFiles[$relativePath] = @{
                content = $content
                lastModified = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                size = $_.Length
                extension = $_.Extension
            }
        }
    }
}

# Create the export object
$export = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    projectRoot = $projectRoot
    files = $codeFiles
}

# Export to JSON file
$export | ConvertTo-Json -Depth 100 | Out-File $outputFile -Encoding UTF8

Write-Host "Export completed to $outputFile"
Write-Host "Total files exported: $($codeFiles.Count)"