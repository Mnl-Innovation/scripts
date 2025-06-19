function Get-SharedLinksViaAPI {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret,
        [string]$TargetUser,
        [string]$ExportPath = "SharedLinks.csv"
    )
    
    # Obtener token de acceso
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://graph.microsoft.com/.default"
    }
    
    $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method Post -Body $body -ContentType "application/x-www-form-urlencoded"
    
    $headers = @{
        "Authorization" = "Bearer $($tokenResponse.access_token)"
        "Content-Type"  = "application/json"
    }

    # Obtener archivos desde la raíz
    $driveItemsUri = "https://graph.microsoft.com/v1.0/users/$TargetUser/drive/root/children"
    $driveItems = Invoke-RestMethod -Uri $driveItemsUri -Headers $headers

    $sharedFiles = @()

    foreach ($item in $driveItems.value) {
        $permissionsUri = "https://graph.microsoft.com/v1.0/users/$TargetUser/drive/items/$($item.id)/permissions"
        try {
            $permissions = Invoke-RestMethod -Uri $permissionsUri -Headers $headers
        } catch {
            Write-Warning "No se pudieron obtener permisos para $($item.name): $_"
            continue
        }

        if ($permissions.value.Count -gt 0) {
            foreach ($perm in $permissions.value) {
                $sharedFiles += [PSCustomObject]@{
                    FileName   = $item.name
                    FileId     = $item.id
                    WebUrl     = $item.webUrl
                    SharedWith = $perm.grantedTo?.user?.email
                    Roles      = ($perm.roles -join '/')
                }
            }
        }
    }

    # Exportar a CSV
    $sharedFiles | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Archivo CSV exportado a: $ExportPath"

    return $sharedFiles
}

# Uso del script
$SharedLinks = Get-SharedLinksViaAPI `
    -TenantId "aqui tu_tenant_id" `
    -ClientId "aqui tu_client_id" `
    -ClientSecret "aqui tu_client_secret" `
    -TargetUser "correo@dominio.com" `
    -ExportPath "C:\Users\user\Desktop\SharedLinks_Audit.csv"
