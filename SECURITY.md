# Publication and security policy

This public repository must never contain:

- passwords, authentication tokens, API keys or recovery codes;
- `.env` files or credential-bearing configuration;
- personal save files, SQLite databases or private player histories;
- macOS signing identities, certificates or provisioning material;
- absolute local-machine paths, account identifiers or private logs;
- compiled application bundles or debug symbols;
- third-party player databases, images or datasets without redistribution permission.

Before each daily release:

1. Review the exact files selected for upload.
2. Search staged text for credential-like names and high-entropy values.
3. Reject local paths, databases, binary bundles and generated saves.
4. Confirm that third-party content has a publication-compatible licence.
5. Publish only the smallest coherent source or documentation slice.

If a secret is ever committed, remove it from the repository history and rotate it immediately. Deleting the visible file alone is not sufficient.

Security issues should be reported privately to the repository owner rather than placed in a public issue.

