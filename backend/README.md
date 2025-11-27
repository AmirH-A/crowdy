# Backend API Service simple one :)

We could using MVC for this one as well its make it more better in structure.

Minimal backend service for interacting with the CrowdfundCampaign smart contract.

## Setup

1. Install dependencies:

```bash
npm install
```

2. Create `.env` file:

```bash
RPC_URL=http://127.0.0.1:8545
CONTRACT_ADDRESS=0xYourDeployedContractAddress
PRIVATE_KEY=0xYourPrivateKey
PORT=3000
```

3. Start the server:

```bash
npm start
```

## Environment Variables

- `RPC_URL`: Ethereum node RPC URL (default: http://127.0.0.1:8545)
- `CONTRACT_ADDRESS`: Deployed CrowdfundCampaign contract address (required)
- `PRIVATE_KEY`: Private key for signing transactions (required)
- `PORT`: Server port (default: 3000)
