# PoC - Azure DevOps Api Automation

## Table of Contents

- [PoC - Azure DevOps Api Automation](#poc---azure-devops-api-automation)
  - [Table of Contents](#table-of-contents)
  - [Disclaimer](#disclaimer)
  - [Description](#description)
  - [Pre-requisites](#pre-requisites)
  - [How to use](#how-to-use)

## Disclaimer

This project is a Proof of Concept (PoC) and is not intended to be used in production environments. The code is provided as-is with no warranties and it is the responsibility of the user to test and validate the code before using it in a production environment.

## Description

This project is a Proof of Concept (PoC) to automate the Azure DevOps API using OAuth2.0 authentication with client credentials flow and Postman.

## Pre-requisites

- [Postman](https://www.postman.com/downloads/)
- [PowerShell 7.3](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.3)
- [Microsoft Graph PowerShell SDK](https://docs.microsoft.com/en-us/graph/powershell/installation)

## How to use

1. Clone this repository
2. Open the PowerShell 7.3 and the script below:

    ```powershell
        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process
        .\Setup-POC.ps1 -TenantId "<TenantId>" -AppName "<AppName>"
    ```

    Replace the parameters with the appropriate values:

    - **TenantId**: Azure AD Tenant Id
    - **AppName**: Azure AD Application Name to be created

    The script will ask for a certificate password so a self-signed X509 certificate can be created and exported to the current directory. An Azure AD Application will be created with that certificate as credential.

    The script will also create in the current directory a Postman collection with the appropriate values to be used in step 4. The collection file will have the same name as the Azure AD Application.

3. Go to your Azure DevOps Organization and add as a user the Azure AD application created in the previous step. For that, go to `Organization Settings` > `Users` > `Add users` > `Search for the Azure AD Application`. Keep the access level as `Basic`, select the appropriate projects you want to give access to, uncheck the box `Send email invites (to Users only)` and click on `Add`.

4. Open the Postman and import the collection created in the step 2. To do that, click on `Import` > `Files` and select the collection file.

5. Run the collection and check the results
