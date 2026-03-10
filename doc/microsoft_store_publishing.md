# Microsoft Store Publishing

To automatically publish the application to the Microsoft Store via GitHub Actions, specific secrets must be configured in your GitHub repository.

## Required GitHub Secrets

You need to set up the following secrets in your repository settings under **Settings > Secrets and variables > Actions > New repository secret**.

1. **`TENANT_ID`**
   - **What it is:** The Azure Active Directory (Microsoft Entra ID) Tenant ID associated with your Microsoft Partner Center account.
   - **Where to get it:** Go to the [Azure Portal](https://portal.azure.com/) -> Microsoft Entra ID -> Overview. Copy the "Tenant ID" value.

2. **`CLIENT_ID`**
   - **What it is:** The Application (client) ID of the Azure AD App Registration authorized to publish apps on your behalf.
   - **Where to get it:** Azure Portal -> Microsoft Entra ID -> App registrations -> Select your app (or create a new one). Copy the "Application (client) ID".

3. **`CLIENT_SECRET`**
   - **What it is:** A secure token representing the password for the App Registration.
   - **Where to get it:** Azure Portal -> Microsoft Entra ID -> App registrations -> Your app -> Certificates & secrets -> New client secret. Copy the the raw "Value". *(Note: This value is only visible immediately after creation).*

4. **`SELLER_ID`**
   - **What it is:** Your Microsoft Partner Center Publisher ID.
   - **Where to get it:** [Partner Center](https://partner.microsoft.com/en-us/dashboard/) -> Settings (gear icon) -> Account settings -> Organization profile -> Identifiers. Look for the "Publisher ID" under Windows publisher details. Example: `12345678`.

5. **`APP_ID`**
   - **What it is:** The unique identifier for your application inside the Microsoft Store.
   - **Where to get it:** Partner Center -> Your App -> App management -> App identity. Copy the "Store ID" (typically a 12-character alphanumeric string like `9NNNNNNNNNNN`). *(Note: Do NOT confuse this with the Package Family Name).*

## Partner Center Architecture Requirements

For automatic submissions to work, your App Registration must be linked and granted access in the Microsoft Partner Center.

1. **Link Azure AD Context:** Ensure your Partner Center account is connected to the same Azure AD tenant. (Settings -> Account settings -> User management -> Azure AD).
2. **Setup Users Roles:** Under "User management" in Partner Center, click "Add user" -> "Create Azure AD applications". Add your newly created App Registration and assign it the **"Manager"** or **"Developer"** role to grant store submission rights.
3. **First Manual Submission:** The Microsoft Store Submission API expects the application to already exist. Ensure you have made at least one manual submission (even if it's only a metadata shell to answer the age-rating questionnaires).

The GitHub Action (`publish-ms-store.yml`) monitors newly published GitHub Releases and submits the `.msix` file artifact directly to the Microsoft Store seamlessly.
