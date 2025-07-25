# App Signing Setup for Play Store Release

## CRITICAL: You MUST use your existing signing key!

Since this app is already published on Google Play Store, you **MUST** use the same signing key that was used for the original publication. Using a different key will cause Google Play to reject your update.

## What you need to find:

1. **Keystore file**: Look for a file with extension `.jks` or `.keystore`
2. **Keystore password**: The password you used to create the keystore
3. **Key alias**: The alias name for your key (often something like "key" or "upload")
4. **Key password**: The password for the specific key alias

## Common locations to check:

- In your project's `android/` folder
- In your user directory (C:\Users\[YourName]\.android\)
- On external drives or cloud storage where you backup important files
- In email attachments if you shared it before

## Once you find your signing key:

### Step 1: Copy the keystore file
Copy your `.jks` or `.keystore` file to:
`C:\Users\Katende Chris\OneDrive\Desktop\APP\aws_app_reengineering\android\app\`

### Step 2: Create key.properties file
Create a file called `key.properties` in the `android/` folder with this content:

```
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=../app/your-keystore-filename.jks
```

Replace the values with your actual credentials.

### Step 3: Update build.gradle.kts
We'll need to modify the Android build configuration to use your signing key.

## If you've lost your signing key:

If you cannot find your original signing key, you have these options:

1. **Contact Google Play Support**: They might be able to help in some cases
2. **Publish as a new app**: You'd need to change the package name and publish as a completely new application
3. **Use Play App Signing**: If you enrolled in Play App Signing, Google might have a backup

## Security Note:
- Never share your keystore file or passwords
- Keep multiple secure backups of your keystore
- The keystore file and passwords are required for ALL future updates

## Next Steps:
Once you complete the signing setup, we can proceed to build the release APK/Bundle.
