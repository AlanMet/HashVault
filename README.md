# Flutter Password Manager

## Overview
This Flutter-based password manager provides a secure way to store and manage passwords. It includes a simple authentication system with password hashing and encryption, as well as features to ensure security and usability.

![image](https://github.com/user-attachments/assets/328bb1ed-e5a5-4fe0-9b29-b15f88491473)


## Features
- **Secure Authentication**: Users must enter a password to access their stored credentials. The password hash is encrypted and stored separately.
- **Failed Attempt Handling**: After 10 failed login attempts, all stored data is deleted.
- **Password Storage**: Credentials are encrypted and stored securely in a file.
- **Backup Handling**: The app checks if the password file exists and allows for backup.
- **Password Management UI**: A simple UI that displays stored passwords, hidden by default until revealed.
- **Search Functionality**: Users can search for specific credentials.
- **Security Indicators**: The background color of each password entry indicates its age and reuse:
  - **Orange**: Password has been unchanged for a while or is used twice for different accounts.
  - **Red**: Password has been unchanged for a very long time.
- **Quick Access**: A button to open the associated website directly from the app.

## Flowchart
Check out our [Flowchart](flowchart.md) for an overview of the application's logic.

## Installation
1. Clone the repository:
   

sh
   git clone https://github.com/AlanMet/HashVault.git


2. Navigate to the project folder:
   

sh
   cd hash_vault


3. Install dependencies:
   

sh
   flutter pub get


4. Run the application:
   

sh
   flutter run



## Security Measures
- **Encryption**: All stored passwords are encrypted using AES before being saved.
- **Secure Storage**: Sensitive metadata such as failed attempts is stored in a secure storage mechanism.
- Each client is given a random key which is used to create encryption and decryption keys.
- **Automatic Deletion**: After 10 failed login attempts, all stored data is wiped to prevent brute-force attacks.

## Usage
1. Open the app and enter your password.
2. If the password is correct, the main UI will display stored passwords.
3. Search for passwords, reveal them, or use the quick access button to visit the website.
4. The background color of each password entry provides security insights.

## Development Focus

Currently, the app is focused on implementing solid security features, including strong encryption and fail-safe mechanisms for data protection. Once the security aspects are fully implemented, I will shift focus to improving the UI and UX for a more polished and user-friendly experience.

## License
This project is open-source and available under the GNU License.
