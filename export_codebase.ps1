# PowerShell script to extract relevant files
$projectPath = "C:\VSCode\fftcg_companion_app"  # Adjust this path to your project root
$outputFile = "codebase_export.txt"

# Directories to exclude
$excludeDirs = @(
    '.dart_tool',
    'build',
    '.idea',
    '.vscode',
    'ios',
    'linux',
    'macos',
    'windows',
    'web'
)

# File patterns to include
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

# Create or clear the output file
"FFTCG Companion App Codebase Export" | Out-File $outputFile
"Generated: $(Get-Date -Format 'MM/dd/yyyy HH:mm:ss')" | Add-Content $outputFile
"" | Add-Content $outputFile

# Function to determine the language for code fence
function Get-CodeFenceLanguage {
    param($extension)
    switch ($extension) {
        ".dart"     { "dart" }
        ".gradle"   { "gradle" }
        ".xml"      { "xml" }
        ".pro"      { "proguard" }
        ".properties" { "properties" }
        ".json"     { "json" }
        ".yaml"     { "yaml" }
        default     { "text" }
    }
}

# Get all files matching patterns and excluding specified directories
foreach ($pattern in $includePatterns) {
    Get-ChildItem -Path $projectPath -Filter $pattern -Recurse | 
        Where-Object { 
            $include = $true
            foreach ($dir in $excludeDirs) {
                if ($_.FullName -like "*\$dir\*") {
                    $include = $false
                    break
                }
            }
            $include
        } | ForEach-Object {
            # Add file path as header
            "FILE: $($_.FullName.Replace($projectPath, ''))" | Add-Content $outputFile
            
            # Get language for code fence
            $language = Get-CodeFenceLanguage $_.Extension
            
            # Add code fence with language
            "``````$language" | Add-Content $outputFile
            
            # Add file content
            Get-Content $_.FullName | Add-Content $outputFile
            "``````" | Add-Content $outputFile
            "" | Add-Content $outputFile
        }
}

Write-Host "Codebase exported to: $outputFile"