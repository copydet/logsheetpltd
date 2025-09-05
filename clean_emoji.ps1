Get-ChildItem -Path "lib" -Recurse -Filter "*.dart" | ForEach-Object {
    $content = Get-Content $_.FullName -Encoding UTF8
    
    # Hapus emoji dari print statements
    $content = $content -replace 'print\(''🚀', "print('"
    $content = $content -replace 'print\(''🔄', "print('"
    $content = $content -replace 'print\(''⏰', "print('"
    $content = $content -replace 'print\(''✅', "print('"
    $content = $content -replace 'print\(''❌', "print('"
    $content = $content -replace 'print\(''🔍', "print('"
    $content = $content -replace 'print\(''🧪', "print('"
    $content = $content -replace 'print\(''📝', "print('"
    $content = $content -replace 'print\(''💾', "print('"
    $content = $content -replace 'print\(''🎯', "print('"
    $content = $content -replace 'print\(''🗑️', "print('"
    $content = $content -replace 'print\(''⏳', "print('"
    $content = $content -replace 'print\(''🔧', "print('"
    $content = $content -replace 'print\(''📱', "print('"
    $content = $content -replace 'print\(''⚙️', "print('"
    $content = $content -replace 'print\(''🌐', "print('"
    $content = $content -replace 'print\(''🔐', "print('"
    $content = $content -replace 'print\(''📡', "print('"
    $content = $content -replace 'print\(''💡', "print('"
    $content = $content -replace 'print\(''⚡', "print('"
    $content = $content -replace 'print\(''📊', "print('"
    $content = $content -replace 'print\(''🌡️', "print('"
    $content = $content -replace 'print\(''👂', "print('"
    $content = $content -replace 'print\(''🔔', "print('"
    $content = $content -replace 'print\(''👤', "print('"
    $content = $content -replace 'print\(''🏃', "print('"
    $content = $content -replace 'print\(''📋', "print('"
    $content = $content -replace 'print\(''🗄️', "print('"
    $content = $content -replace 'print\(''🧹', "print('"
    
    # Hapus emoji standalone di tengah teks
    $content = $content -replace '🚀', ''
    $content = $content -replace '🔄', ''
    $content = $content -replace '⏰', ''
    $content = $content -replace '✅', ''
    $content = $content -replace '❌', ''
    $content = $content -replace '🔍', ''
    $content = $content -replace '🧪', ''
    $content = $content -replace '📝', ''
    $content = $content -replace '💾', ''
    $content = $content -replace '🎯', ''
    $content = $content -replace '🗑️', ''
    $content = $content -replace '⏳', ''
    $content = $content -replace '🔧', ''
    $content = $content -replace '📱', ''
    $content = $content -replace '⚙️', ''
    $content = $content -replace '🌐', ''
    $content = $content -replace '🔐', ''
    $content = $content -replace '📡', ''
    $content = $content -replace '💡', ''
    $content = $content -replace '⚡', ''
    $content = $content -replace '📊', ''
    $content = $content -replace '🌡️', ''
    $content = $content -replace '👂', ''
    $content = $content -replace '🔔', ''
    $content = $content -replace '👤', ''
    $content = $content -replace '🏃', ''
    $content = $content -replace '📋', ''
    $content = $content -replace '🗄️', ''
    $content = $content -replace '🧹', ''
    $content = $content -replace '📤', ''
    
    Set-Content -Path $_.FullName -Value $content -Encoding UTF8
    Write-Host "Cleaned: $($_.Name)"
}

Write-Host "Emoji cleanup completed!"
