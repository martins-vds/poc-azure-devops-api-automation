[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param (
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
    $CertificatePassword,
    [Parameter(Mandatory = $false)]
    [switch]
    $Force
)

$ErrorActionPreference = "Stop"

if ($Force -and -not $Confirm) {
    $ConfirmPreference = 'None'
}

if ($PSCmdlet.ShouldProcess($CertificatePath.Name, "Export Private Key")) {
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath, $CertificatePassword, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
    Write-Host $cert.PrivateKey.ExportPkcs8PrivateKeyPem()
}