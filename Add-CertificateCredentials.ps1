[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [Guid]
    $TenantId,
    [Parameter(Mandatory = $true)]
    [Guid]
    $AppId,
    [Parameter(Mandatory = $true)]
    [ValidateScript({ 
            if ( -Not (Test-Path $_ -PathType Leaf) ) {
                throw "Certificate file '$_' does not exist."
            }

            if ( -Not($_.Extension -eq ".pfx") ) {
                throw "Certificate file '$_' is not a PFX file."
            }

            return $true 
        })]
    [System.IO.FileInfo]
    $CertificatePath,
    [Parameter(Mandatory = $true)]
    [securestring]
    $CertificatePassword
)

$ErrorActionPreference = "Stop"

Import-Module AzureAD

Connect-AzureAD -TenantId $TenantId

$app = Get-AzureADApplication -Filter "AppId eq '$AppId'"

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath, $CertificatePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)

$base64Value = [System.Convert]::ToBase64String($cert.GetRawCertData())
$base64Thumbprint = [System.Convert]::ToBase64String($cert.GetCertHash())

New-AzureADApplicationKeyCredential -ObjectId $app.ObjectId `
    -CustomKeyIdentifier $base64Thumbprint `
    -Type AsymmetricX509Cert `
    -Usage Verify `
    -Value $base64Value `
    -StartDate $cert.NotBefore `
    -EndDate $cert.NotAfter