Flutter Password Manager
Overview

This Flutter-based password manager provides a secure way to store and manage passwords. I've focused on the security aspects of the app first, ensuring that data is safely encrypted, stored, and protected. The next steps will involve working on the UI and UX to make the application user-friendly and intuitive.

image
Features

    Secure Authentication: Users must enter a password to access their stored credentials. 
    The password hash is encrypted and stored separately.
    Failed Attempt Handling: After 10 failed login attempts, all stored data is deleted.
    Password Storage: Credentials are encrypted and stored securely in a file.
    Backup Handling: The app checks if the password file exists and allows for backup.
    Password Management UI: A simple UI that displays stored passwords, hidden by default until revealed.
    Search Functionality: Users can search for specific credentials.
    Security Indicators: The background color of each password entry indicates its age and reuse:
        Orange: Password has been unchanged for a while or is used twice for different accounts.
        Red: Password has been unchanged for a very long time.
    Quick Access: A button to open the associated website directly from the app.

Flowchart

Check out our Flowchart for an overview of the application's logic.
Installation

    Clone the repository:

git clone https://github.com/AlanMet/HashVault.git

Navigate to the project folder:

cd hash_vault

Install dependencies:

flutter pub get

Run the application:

    flutter run

Security Measures

    Encryption: All stored passwords are encrypted using AES before being saved.
    Secure Storage: Sensitive metadata such as failed attempts is stored in a secure storage mechanism.
    Automatic Deletion: After 10 failed login attempts, all stored data is wiped to prevent brute-force attacks.

Development Focus

Currently, the app is focused on implementing solid security features, including strong encryption and fail-safe mechanisms for data protection. Once the security aspects are fully implemented, I will shift focus to improving the UI and UX for a more polished and user-friendly experience.
Usage

    Open the app and enter your password.
    If the password is correct, the main UI will display stored passwords.
    Search for passwords, reveal them, or use the quick access button to visit the website.
    The background color of each password entry provides security insights.

Dependencies

License

This project is open-source and available under the GNU License.
