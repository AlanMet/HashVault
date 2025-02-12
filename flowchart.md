# Password Manager Flowchart

This is the flowchart representing the password manager application's logic:

```mermaid
flowchart TD
    A[Start Application] 
    B{Does Encrypted Hash File Exist?}
    C[First Run: No file found]
    D[Prompt User to Set Master Password]
    E[Compute & Hash Password]
    F[Encrypt Hash and Save to File]
    G[Display Login Screen - Password Prompt]
    H[User Submits Password]
    I[Compute Hash of Entered Password]
    J[Read and Decrypt Stored Hash]
    K{Do the Hashes Match?}
    L[Reset Failed Attempts Counter]
    M[Grant Access: Navigate to Main UI]
    N[Increment Failed Attempts Counter]
    O{Failed Attempts >= 10?}
    P[Delete/Wipe All Data Files, Backup, etc.]
    Q[Show Too many attempts Message]
    R[Show Error Message - Incorrect password, attempt X/10]
    S[Return to Password Prompt]
    T[Main UI: Display Records List]
    U[Each Record: Website/App Name, Hidden Password, Colour, and Website Button]
    V[User Interaction: Search, Tap to Reveal, Click Website Button]

    %% Flow begins
    A --> B

    %% File Check
    B -- Yes --> G
    B -- No --> C

    %% First Run Flow
    C --> D
    D --> E
    E --> F
    F --> G

    %% Login Flow
    G --> H
    H --> I
    I --> J
    J --> K

    %% If password correct
    K -- Yes --> L
    L --> M

    %% If password incorrect
    K -- No --> N
    N --> O
    O -- Yes --> P
    P --> Q
    Q --> G
    O -- No --> R
    R --> S
    S --> G

    %% After Successful Login
    M --> T
    T --> U
    U --> V

    %% Style definitions
    %% Generic Grey Nodes (text in black)
    style A fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style B fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style C fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style D fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style E fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style F fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style G fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style H fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style I fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style J fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style K fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style N fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style O fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style S fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style T fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style U fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000
    style V fill:#cccccc,stroke:#333,stroke-width:2px,color:#000000

    %% Success (Green) Nodes (text in black)
    style L fill:#90ee90,stroke:#333,stroke-width:2px,color:#000000
    style M fill:#90ee90,stroke:#333,stroke-width:2px,color:#000000

    %% Error (Red) Nodes (text in black)
    style P fill:#ff9999,stroke:#333,stroke-width:2px,color:#000000
    style Q fill:#ff9999,stroke:#333,stroke-width:2px,color:#000000
    style R fill:#ff9999,stroke:#333,stroke-width:2px,color:#000000

    %% Uniform link style in dark grey
    linkStyle default stroke:#555,stroke-width:2px
