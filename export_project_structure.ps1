# Get the current directory path
$currentPath = Get-Location

# Function to create file structure object
function Get-FileStructure {
    param (
        [string]$path,
        [int]$currentDepth = 0,
        [int]$maxDepth = 50
    )
    
    if ($currentDepth -ge $maxDepth) {
        Write-Warning "Maximum depth reached at path: $path"
        return @()
    }
    
    try {
        $items = Get-ChildItem -Path $path -Force -ErrorAction Stop
        $structure = @()
        
        # Directories to exclude
        $excludeDirs = @(
            '.dart_tool',
            '.git',
            '.idea',
            '.vscode',
            'build',
            'ios',
            'linux',
            'macos',
            'windows',
            'web',
            '.gradle',
            'test',
            'node_modules',
            'bin',
            'obj',
            'dist',
            'ephemeral'
        )

        # File patterns to include
        $includePatterns = @(
            '*.dart',
            'build.gradle',
            'settings.gradle',
            'gradle.properties',
            'gradle-wrapper.properties',
            'AndroidManifest.xml',
            'proguard-rules.pro',
            '*.properties',
            'google-services.json',
            '*.yaml',
            'pubspec.lock'
        )
        
        foreach ($item in $items) {
            # Skip excluded directories and their contents
            if ($item.PSIsContainer -and $excludeDirs -contains $item.Name) {
                continue
            }
            
            # For files, only include those matching the patterns
            if (!$item.PSIsContainer) {
                $matchesPattern = $false
                foreach ($pattern in $includePatterns) {
                    if ($item.Name -like $pattern) {
                        $matchesPattern = $true
                        break
                    }
                }
                if (!$matchesPattern) {
                    continue
                }
            }
            
            $obj = @{
                name = $item.Name
                type = if ($item.PSIsContainer) { "directory" } else { "file" }
                extension = if ($item.PSIsContainer) { $null } else { $item.Extension }
                size = if ($item.PSIsContainer) { $null } else { $item.Length }
                lastModified = $item.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                path = $item.FullName.Replace($currentPath.Path, '').TrimStart('\')
            }
            
            if ($item.PSIsContainer) {
                $obj.children = @(Get-FileStructure -path $item.FullName -currentDepth ($currentDepth + 1) -maxDepth $maxDepth)
                # Only add directories that have matching files
                if ($obj.children.Count -gt 0) {
                    $structure += $obj
                }
            } else {
                $structure += $obj
            }
        }
        
        return $structure
    }
    catch {
        Write-Warning "Error accessing path: $path"
        Write-Warning $_.Exception.Message
        return @()
    }
}

# Generate the structure
$fileStructure = @{
    projectRoot = $currentPath.Path
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    structure = @(Get-FileStructure -path $currentPath)
}

# Create output
try {
    $jsonOutput = $fileStructure | ConvertTo-Json -Depth 100 -Compress
    $jsonOutput | Out-File -FilePath "project-structure.json" -Encoding UTF8
    Write-Host "File structure has been saved to 'project-structure.json'"
    
    # Output some basic statistics
    $totalFiles = ($jsonOutput | Select-String -Pattern '"type":"file"' -AllMatches).Matches.Count
    $totalDirs = ($jsonOutput | Select-String -Pattern '"type":"directory"' -AllMatches).Matches.Count
    Write-Host "Total files: $totalFiles"
    Write-Host "Total directories: $totalDirs"
}
catch {
    Write-Error "Error saving JSON file: $_"
}