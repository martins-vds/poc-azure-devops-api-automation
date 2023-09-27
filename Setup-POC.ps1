[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [Guid]
    $TenantId,
    [Parameter(Mandatory = $true)]
    [string]
    $AppName,
    [Parameter(Mandatory = $true)]
    [securestring]
    $CertificatePassword
)

$ErrorActionPreference = "Stop"

function Create-Certificate {
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Subject,
        [Parameter(Mandatory = $true)]
        [securestring]
        $CertificatePassword
    )

    $ErrorActionPreference = "Stop"

    $certName = "$($Subject.ToLower() -replace "[^a-zA-Z0-9]", "_")-$(New-Guid)"
    $certSubject = "CN=$Subject"
    $certStoreLocation = "Cert:\CurrentUser\My"
    $certFile = "$PSScriptRoot\$certName.pfx"

    New-SelfSignedCertificate -Subject $certSubject -CertStoreLocation $certStoreLocation -KeyExportPolicy Exportable -KeySpec Signature -KeyAlgorithm RSA -KeyLength 2048 | Export-PfxCertificate -FilePath $certFile -Password $CertificatePassword | Out-Null

    Get-ChildItem $certStoreLocation | Where-Object { $_.Subject -match $certSubject } | Remove-Item

    $newCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($certFile, $CertificatePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)

    return @{
        Object              = $newCert
        Path                = $certFile
        PrivateKey          = $newCert.PrivateKey.ExportPkcs8PrivateKeyPem()
        Thumbprint          = $newCert.Thumbprint
        Base64Value         = [System.Convert]::ToBase64String($newCert.GetRawCertData())
        Base64Thumbprint    = [System.Convert]::ToBase64String($newCert.GetCertHash())
        Base64UrlThumbprint = [System.Convert]::ToBase64String($newCert.GetCertHash()) -replace '\+', '-' -replace '/', '_' -replace '=', ''
        StartDate           = $newCert.NotBefore
        EndDate             = $newCert.NotAfter
    }
}

function Get-AzureDevOpsPermissions {
    
    $devops = Get-MgServicePrincipal -Filter "DisplayName eq 'Azure DevOps'"
    $permission = $devops.Oauth2PermissionScopes | Where-Object { $_.Value -eq 'user_impersonation' } | Select-Object -First 1

    return @{
        ResourceAppId   = $devops.AppId
        ResourceAccessId = $permission.Id
    }
}

function Register-AzureApplication {
    param (
        [string]
        $AppName,
        [Guid]
        $ResourceAppId,
        [Guid]
        $ResourceAccessId
    )

    $app = Get-MgApplication -Filter "DisplayName eq '$AppName'"

    if($null -eq $app) {
        $app = New-MgApplication -DisplayName $AppName
        New-MgServicePrincipal -AppId $app.AppId -DisplayName $AppName | Out-Null

    }else{
        Write-Warning "Application '$AppName' already exists. Updating..."
    }

    $params = @{
        requiredResourceAccess = @(
            @{
                resourceAppId  = $ResourceAppId
                resourceAccess = @(
                    @{
                        id   = $ResourceAccessId
                        type = "Scope"
                    }
                )
            }
        )
    }

    Update-MgApplication -ApplicationId $app.Id -BodyParameter $params

    return $app
}

function Update-AzureApplication {
    param (
        [Parameter(Mandatory = $true)]
        [Guid]
        $AppId,
        [Parameter(Mandatory = $true)]
        $Cert
    )
    
    $params = @{
        keyCredentials = @(
            @{
                customKeyIdentifier = [System.Text.Encoding]::ASCII.GetBytes($Cert.Base64Thumbprint)
                endDateTime         = $Cert.EndDate
                keyId               = [System.Guid]::NewGuid()
                startDateTime       = $Cert.StartDate
                type                = "AsymmetricX509Cert"
                usage               = "Verify"
                key                 = [System.Text.Encoding]::ASCII.GetBytes($Cert.Base64Value)
            }
        )
    }

    Update-MgApplication -ApplicationId $AppId -BodyParameter $params
}

function Update-PostmanCollection {
    param (
        [Parameter(Mandatory = $true)]
        [Guid]
        $TenantId,
        [Parameter(Mandatory = $true)]
        [string]
        $AppName,
        [Parameter(Mandatory = $true)]
        [Guid]
        $AppId,
        [Parameter(Mandatory = $true)]
        [string]
        $Scope,
        [Parameter(Mandatory = $true)]
        [string]
        $CertificatePrivateKey,
        [Parameter(Mandatory = $true)]
        [string]
        $CertificateThumbprint
    )
    
    $collection = Get-Content "$PSScriptRoot\template.postman_collection.json" -Encoding utf8 | ConvertFrom-Json -Depth 10

    $collection.info.name = "$($collection.info.name) - $AppName"

    $collection.variable | ForEach-Object {
        $variable = $_

        switch ($variable.key) {
            "az_devops_scope" { $variable.value = $Scope; Break }
            "cert_privatey_key" { $variable.value = $CertificatePrivateKey; Break }
            "cert_thumbprint" { $variable.value = $CertificateThumbprint; Break }
            "tenant_id" { $variable.value = $TenantId; Break }
            "client_id" { $variable.value = $AppId; Break }
            "account_name" { $variable.value = $AppName; Break }
        }
    }

    $collectionName = $AppName.ToLower() -replace "[^a-zA-Z0-9]", "_"

    $collection | ConvertTo-Json -Depth 10 | Out-File "$PSScriptRoot\$collectionName.postman_collection.json" -Encoding utf8 -Force
}

Connect-MgGraph -TenantId $TenantId -Scopes "Application.ReadWrite.All", "DelegatedPermissionGrant.ReadWrite.All" -NoWelcome

Write-Host "Creating certificate..."

$cert = Create-Certificate -Subject $AppName -CertificatePassword $CertificatePassword

Write-Host "Getting Azure DevOps permissions..."

$devopsPermissions = Get-AzureDevOpsPermissions

Write-Host "Creating application '$AppName' in Azure AD..."

$app = Register-AzureApplication -AppName $AppName -ResourceAppId $devopsPermissions.ResourceAppId -ResourceAccessId $devopsPermissions.ResourceAccessId

Write-Host "Adding certificate to application..."

Update-AzureApplication -AppId $app.Id -Cert $cert

Write-Host "Updating Postman collection..."

Update-PostmanCollection -TenantId $TenantId -AppName $AppName -AppId $app.AppId -Scope "$($devopsPermissions.ResourceAppId)/.default" -CertificatePrivateKey $cert.PrivateKey -CertificateThumbprint $cert.Base64UrlThumbprint

Write-Host "Done." -ForegroundColor Green