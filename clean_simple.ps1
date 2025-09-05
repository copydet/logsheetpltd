# Simple emoji cleanup script
Get-ChildItem -Path "lib" -Recurse -Filter "*.dart" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw -Encoding UTF8
    
    # Remove common patterns with emoji
    $content = $content -replace "print\('.[^']*:", "print('"
    $content = $content -replace "print\('.[^']*\|", "print('"  
    $content = $content -replace "print\('.[^']*-", "print('"
    $content = $content -replace "print\('.[^']*\]", "print('"
    
    # Clean up multiple spaces in print statements
    $content = $content -replace "print\('\s+", "print('"
    
    Set-Content -Path $_.FullName -Value $content -Encoding UTF8 -NoNewline
    Write-Host "Processed: $($_.Name)"
}

Write-Host "Cleanup completed!"
