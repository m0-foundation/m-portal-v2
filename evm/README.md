# Portal v2 (EVM)

This folder contains the EVM implementation of PortalV2. It uses Foundry for building and testing the contracts. 

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Solidity 0.8.34

### Setup

```bash
# Clone the repository
git clone git@github.com:m0-foundation/m-portal-v2.git
cd m-portal-v2/evm

# Install dependencies
forge install

# Build contracts
forge build
```
### Test

```bash
# Test contracts
forge test

# Code coverage
forge coverage
```

### Format code

```bash
forge fmt
```
