function Get-PublicSharingLinksRecursive {
    param(
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret,
        [string]$TargetUser
    )

    # Obtener token de acceso
    $body = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = "https://graph.microsoft.com/.default"
    }

    $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Method POST -Body $body -ContentType "application/x-www-form-urlencoded"
    $headers = @{
        Authorization = "Bearer $($tokenResponse.access_token)"
        "Content-Type" = "application/json"
    }

    # Obtener ID del drive del usuario
    $drive = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/$TargetUser/drive" -Headers $headers
    $driveId = $drive.id

    $sharedPublicly = New-Object System.Collections.Generic.List[object]

    function Traverse-ItemsRecursively {
        param([string]$itemId, [string]$path)

        $url = "https://graph.microsoft.com/v1.0/drives/$driveId/items/$itemId/children"
        try {
            do {
                $response = Invoke-RestMethod -Uri $url -Headers $headers
                foreach ($item in $response.value) {
                    $currentPath = "$path/$($item.name)"

                    # Obtener permisos del ítem
                    $permissionsUrl = "https://graph.microsoft.com/v1.0/drives/$driveId/items/$($item.id)/permissions"
                    try {
                        $permissions = Invoke-RestMethod -Uri $permissionsUrl -Headers $headers
                        foreach ($permission in $permissions.value) {
                            if ($permission.link.scope -eq "anonymous") {
                                $sharedPublicly.Add([PSCustomObject]@{
                                    FileName = $item.name
                                    WebUrl   = $item.webUrl
                                    LinkType = $permission.link.type
                                    Scope    = $permission.link.scope
                                    Path     = $currentPath
                                })
                            }
                        }
                    } catch {
                        Write-Warning "No se pudieron obtener permisos para $($item.name): $_"
                    }

                    # Si es carpeta, recorrer recursivamente
                    if ($item.folder) {
                        Traverse-ItemsRecursively -itemId $item.id -path $currentPath
                    }
                }

                $url = $response.'@odata.nextLink'
            } while ($url)
        } catch {
            Write-Warning "Error al recorrer el contenido de ${path}: $_"
        }
    }

    # Iniciar desde la raíz del drive
    $rootId = (Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/drives/$driveId/root" -Headers $headers).id
    Traverse-ItemsRecursively -itemId $rootId -path ""

    # Exportar resultados
    $sharedPublicly | Export-Csv -Path "./Shared_Public_Links.csv" -NoTypeInformation -Encoding UTF8
    return $sharedPublicly
}

# Ejecutar la función con tus parámetros
$results = Get-PublicSharingLinksRecursive -TenantId "Tenant ID" -ClientId "Client ID" -ClientSecret "Client secret" -TargetUser "correo@dominio.com"
$results

