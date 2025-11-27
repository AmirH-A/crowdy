# CrowdfundCampaign - Blockchain Crowdfunding Platform

A decentralized crowdfunding platform built on Ethereum, consisting of a Solidity smart contract and a minimal backend API service.

We could implement the MVC also for the back-end :) its make the backend more clean

## Table of Contents

- [Architecture](#architecture)
- [Smart Contract Features](#smart-contract-features)
- [Backend API](#backend-api)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Installation & Setup](#installation--setup)
- [Testing](#testing)
- [Deployment](#deployment)
- [API Documentation](#api-documentation)
- [Project Structure](#project-structure)
- [Assumptions](#assumptions)
- [Security Considerations](#security-considerations)

## Architecture

### Smart Contract (`CrowdfundCampaign.sol`)

The contract implements a crowdfunding system with the following components:

- **Campaign Storage**: Uses a dynamic array to store multiple campaigns
- **Campaign Structure**: Each campaign contains:
  - `owner`: Address of the campaign creator
  - `goalAmount`: Target funding amount (in wei)
  - `deadline`: Unix timestamp when the campaign ends
  - `title` & `description`: Campaign metadata
  - `totalRaised`: Mapping of token address to total raised amount
  - `contributions`: Nested mapping tracking individual contributions (token => contributor => amount)
  - `withdrawn`: Boolean flag indicating if funds have been withdrawn

### Backend Service

A Node.js/Express API that provides REST endpoints to interact with the smart contract:

- Uses `ethers.js` v6 for blockchain interaction
- Supports both read (view) and write (transaction) operations
- Handles ETH and ERC20 token contributions
- Contract ABI loaded from separate JSON file

## Smart Contract Features

### 1. Create Campaign

- Anyone can create a campaign
- Requires: `goalAmount > 0`, `deadline > current timestamp`
- Emits `CampaignCreated` event

### 2. Contribute

- Supports ETH and ERC20 token contributions
- Contributions must be > 0
- Only allowed before campaign deadline
- Tracks individual contributor amounts
- Emits `ContributionReceived` event

### 3. Withdraw Funds (Owner Only)

- Only campaign owner can withdraw
- Requires:
  - Goal reached (`raisedAmount >= goalAmount`)
  - Deadline passed
  - Not already withdrawn
- Locks campaign after withdrawal (prevents further actions)
- Emits `FundsWithdrawn` event

### 4. Refund Contributors

- Available if goal not met AND deadline passed
- Contributors can claim refunds individually
- Prevents double refunds (contribution set to 0 after refund)
- Prevents refunds after withdrawal
- Emits `RefundIssued` event

## Backend API

### Endpoints

#### `GET /health`

Health check endpoint.

**Response:**

```json
{
  "status": "ok",
  "contractAddress": "0x..."
}
```

#### `GET /campaigns`

Reads all campaigns from the blockchain.

**Response:**

```json
{
  "campaigns": [
    {
      "id": 0,
      "owner": "0x...",
      "goalAmount": "1000000000000000000",
      "deadline": "1234567890",
      "title": "My Campaign",
      "description": "Campaign description",
      "raisedAmount": "500000000000000000",
      "withdrawn": false
    }
  ],
  "total": 1
}
```

#### `POST /campaigns`

Creates a new campaign.

**Request Body:**

```json
{
  "goalAmount": "1000000000000000000",
  "deadline": "1735689600",
  "title": "My Campaign",
  "description": "Campaign description"
}
```

**Response:**

```json
{
  "success": true,
  "transactionHash": "0x...",
  "campaignId": "0",
  "receipt": {
    "blockNumber": 12345,
    "gasUsed": "150000"
  }
}
```

#### `POST /contribute`

Contributes to a campaign.

**Request Body (ETH):**

```json
{
  "campaignId": 0,
  "amount": "100000000000000000"
}
```

**Request Body (ERC20 Token):**

```json
{
  "campaignId": 0,
  "amount": "100000000000000000",
  "token": "0xTokenAddress"
}
```

#### `POST /refund`

Claims a refund for contributions.

**Request Body:**

```json
{
  "campaignId": 0,
  "token": "0x0000000000000000000000000000000000000000"
}
```

#### `POST /withdraw`

Withdraws funds (campaign owner only).

**Request Body:**

```json
{
  "campaignId": 0
}
```

## Prerequisites

- **Node.js** (v18 or higher)
- **Foundry** (for smart contract development)
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```
- **Ethereum Node** (Anvil for local development, or Infura/Alchemy for testnets/mainnet)

## Quick Start

The easiest way to get started is using the Makefile:

```bash
# Install dependencies
make install

# Deploy contract, setup backend, and start everything
make run

# Run all tests
make test-all

# Stop everything
make stop-all
```

See [README-MAKEFILE.md](README-MAKEFILE.md) for detailed Makefile usage.

## Installation & Setup

### Option 1: Using Makefile (Recommended)

```bash
make install
make run
```

The Makefile will automatically:

- Start Anvil local blockchain
- Deploy the contract
- Create backend `.env` file
- Start the backend server

### Option 2: Manual Setup

#### 1. Install Dependencies

```bash
cd crowdy
forge install

cd ../backend
npm install
```

#### 2. Deploy Contract

Start Anvil:

```bash
anvil
```

Deploy contract:

```bash
cd crowdy
forge script script/Crowdy.s.sol:CrowdfundCampaignScript \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

#### 3. Configure Backend

Create `.env` file in `backend/` directory:

```
RPC_URL=http://127.0.0.1:8545
CONTRACT_ADDRESS=0xYourDeployedContractAddress
PRIVATE_KEY=0xYourPrivateKey
PORT=3000
```

#### 4. Start Backend

```bash
cd backend
npm start
```

## Testing

### Smart Contract Tests

```bash
cd crowdy
forge test
```

**Test Coverage:**

- Campaign creation
- ETH and ERC20 contributions
- Withdrawal logic (owner only, goal met, deadline passed)
- Refund logic (goal not met, deadline passed)
- Reverts for invalid operations
- Edge cases (deadline exactly at block timestamp, multiple contributions, etc.)
- Double refund prevention
- Campaign locking after withdrawal

**Test Results:** 21 tests, all passing

### Backend API Tests

```bash
cd backend
./test-api.sh
```

Or using Makefile:

```bash
make test-backend
```

### Run All Tests

```bash
make test-all
```

## Deployment

### Local Development

Using Makefile:

```bash
make run
```

Manual deployment:

```bash
anvil
cd crowdy
forge script script/Crowdy.s.sol:CrowdfundCampaignScript \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Testnet Deployment

```bash
export RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_KEY
export PRIVATE_KEY=0xYourPrivateKey

cd crowdy
forge script script/Crowdy.s.sol:CrowdfundCampaignScript \
  --rpc-url $RPC_URL \
  --broadcast \
  --private-key $PRIVATE_KEY \
  --verify \
  --etherscan-api-key YOUR_ETHERSCAN_API_KEY
```

Update backend `.env` with testnet RPC URL and contract address.

## Assumptions

1. **ETH as Primary Currency**: The contract uses ETH (address(0)) as the primary currency for goal tracking. While ERC20 tokens are supported for contributions, the goal is measured in ETH only.

2. **Single Withdrawal**: Once funds are withdrawn, the campaign is locked and no further actions (contributions, refunds) are possible.

3. **Refund Mechanism**: Refunds are only available if:

   - The deadline has passed
   - The ETH goal was not met
   - The campaign has not been withdrawn

4. **Contribution Tracking**: The contract tracks contributions per token type. A user can contribute both ETH and ERC20 tokens to the same campaign.

5. **Deadline Enforcement**: Contributions are blocked at or after the deadline timestamp (`block.timestamp >= deadline`).

6. **No Partial Withdrawals**: The owner must withdraw all funds at once when conditions are met.

7. **Backend Signer**: The backend uses a single private key for all transactions. In production, consider implementing proper authentication and authorization.

8. **Gas Optimization**: The contract uses mappings for efficient lookups, but stores campaign data in an array for enumeration.

9. **No Reentrancy Protection**: The contract uses OpenZeppelin's SafeERC20 for token transfers, but doesn't include explicit reentrancy guards. For production, we consider adding ReentrancyGuard.

10. **Event Indexing**: Events use indexed parameters for efficient filtering in off-chain applications.

## Security Considerations

1. **Access Control**:

   - Withdrawal is restricted to campaign owners
   - Uses `msg.sender` checks to prevent unauthorized access

2. **Integer Overflow**:

   - Solidity 0.8.20+ has built-in overflow protection
   - Uses SafeERC20 for token transfers

3. **Front-running**:

   - Contributors should be aware that transactions are public
   - Consider using commit-reveal schemes for sensitive campaigns

4. **Private Key Management**:

   - Backend private keys should be stored securely (use environment variables, key management services)
   - Never commit private keys to version control

5. **Input Validation**:

   - Contract validates all inputs (amounts > 0, deadlines in future, etc.)
   - Backend should also validate inputs before sending transactions

6. **Gas Limits**:
   - Consider gas costs when contributing small amounts
   - Backend should handle transaction failures gracefully

## Project Structure

```
toman-home-assignment/
├── crowdy/                    # Foundry project
│   ├── src/
│   │   └── CrowdfundCampaign.sol
│   ├── test/
│   │   └── Crowdy.t.sol
│   ├── script/
│   │   └── Crowdy.s.sol
│   └── foundry.toml
├── backend/                   # Node.js backend
│   ├── index.js
│   ├── package.json
│   ├── contract-abi.json     # Contract ABI (separated)
│   ├── test-api.sh           # API test script
│   └── .env                   # Environment variables (generated)
├── Makefile                   # Automation script
├── README.md                  # This file
└── README-MAKEFILE.md         # Makefile usage guide
```

## Development

### Format Code

```bash
cd crowdy
forge fmt
```

### Gas Snapshots

```bash
cd crowdy
forge snapshot
```

### Build

```bash
cd crowdy
forge build
```

### View Logs

```bash
tail -f /tmp/backend.log
tail -f /tmp/anvil.log
```
