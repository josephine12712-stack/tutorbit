# Tutorbit 🗂️

A decentralized tutoring platform built on the Stacks blockchain that issues proof-of-completion NFTs for tutoring sessions.

## Overview

Tutorbit revolutionizes the tutoring industry by providing verifiable, blockchain-based proof of educational achievements. Students receive unique NFTs as certificates for completing tutoring sessions, creating a permanent, tamper-proof record of their learning journey.

## Features

### Core Functionality
- **Session NFT Minting**: Create unique NFTs for each completed tutoring session
- **Verification System**: Immutable proof-of-completion certificates on the blockchain
- **Tutor Registry**: Decentralized registry for verified tutors
- **Session Management**: Complete lifecycle management of tutoring sessions

### Smart Contracts
- **Tutorbit Core**: Main contract handling NFT minting and session management
- **Tutor Registry**: Contract managing tutor verification and reputation

## How It Works

1. **Tutor Registration**: Tutors register on the platform and get verified
2. **Session Creation**: Tutors create tutoring sessions with specific criteria
3. **Session Completion**: Students complete sessions with verified tutors
4. **NFT Issuance**: Proof-of-completion NFTs are automatically minted
5. **Verification**: Anyone can verify the authenticity of educational achievements

## Smart Contract Architecture

### Tutorbit Core Contract
- Manages the main tutoring session lifecycle
- Handles NFT minting for completed sessions
- Tracks session metadata and completion status
- Implements access controls and security measures

### Tutor Registry Contract  
- Maintains a registry of verified tutors
- Handles tutor application and verification process
- Manages tutor reputation and credentials
- Provides public interface for tutor verification

## Technical Stack

- **Blockchain**: Stacks (Bitcoin Layer 2)
- **Smart Contract Language**: Clarity
- **Development Framework**: Clarinet
- **Testing**: Vitest + TypeScript

## Benefits

### For Students
- Permanent, verifiable proof of learning achievements
- Portable educational credentials
- Enhanced resume with blockchain-verified certificates
- Incentivized learning through tokenization

### For Tutors
- Decentralized platform with lower fees
- Verifiable reputation system
- Automated session completion verification
- Direct compensation without intermediaries

### For Institutions
- Easy verification of student achievements
- Reduced credential fraud
- Streamlined admissions processes
- Integration with existing educational systems

## Development

### Prerequisites
- Clarinet CLI installed
- Node.js and npm
- Git

### Setup
```bash
# Clone the repository
git clone <repository-url>
cd tutorbit

# Install dependencies
npm install

# Check contract syntax
clarinet check

# Run tests
npm test
```

### Project Structure
```
tutorbit/
├── contracts/
│   ├── tutorbit-core.clar      # Main tutoring session contract
│   └── tutor-registry.clar     # Tutor verification contract
├── tests/
├── settings/
├── Clarinet.toml
└── package.json
```

## Usage

### Deploying Contracts
```bash
# Deploy to local devnet
clarinet deploy --local

# Deploy to testnet
clarinet deploy --testnet
```

### Interacting with Contracts
```bash
# Check contract status
clarinet check

# Run specific test
clarinet test tests/tutorbit-core_test.ts
```

## Roadmap

- [ ] MVP deployment on Stacks testnet
- [ ] Web application frontend
- [ ] Mobile application
- [ ] Integration with major educational platforms
- [ ] Advanced analytics and reporting
- [ ] Multi-language support

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contact

For questions, suggestions, or collaboration opportunities, please reach out through our GitHub repository.

---

*Building the future of verifiable education, one session at a time.*
