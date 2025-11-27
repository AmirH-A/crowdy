# Makefile Usage Guide

## Quick Start

```bash
make install
make run
make test-all
make stop-all
```

## Available Commands

### Setup & Installation

- `make install` - Install dependencies
- `make build` - Build smart contract
- `make setup-env` - Create .env file

### Blockchain & Deployment

- `make start-anvil` - Start Anvil
- `make stop-anvil` - Stop Anvil
- `make deploy` - Deploy contract

### Backend

- `make start-backend` - Start backend server
- `make stop-backend` - Stop backend server
- `make test-backend` - Test backend API

### Testing

- `make test` - Run contract tests
- `make test-contract` - Run contract tests
- `make test-backend` - Test backend API
- `make test-all` - Run all tests

### Utilities

- `make run` - Deploy and start everything
- `make stop-all` - Stop all services
- `make status` - Show service status
- `make clean` - Clean temporary files
- `make help` - Show all commands

## Workflow Examples

### Development Workflow

```bash
make install
make build
make test
make run
make test-all
make status
make stop-all
```

### Testing Workflow

```bash
make run
make test-backend
make test-contract
make test-all
```

### Redeploy After Changes

```bash
make build
make deploy
make setup-env
make stop-backend
make start-backend
```

## Service URLs

- Anvil: http://127.0.0.1:8545
- Backend: http://localhost:3000
- Contract Address: Saved in `.env`

## Logs

```bash
tail -f /tmp/backend.log
tail -f /tmp/anvil.log
cat /tmp/deploy.log
```

## Troubleshooting

### Services won't start

```bash
make stop-all
make clean
make run
```

### Port already in use

```bash
lsof -i :8545
lsof -i :3000
```

### Contract deployment fails

```bash
make start-anvil
cat /tmp/deploy.log
```

## Environment Variables

The Makefile creates `.env` in `backend/` with:

- `RPC_URL`
- `CONTRACT_ADDRESS`
- `PRIVATE_KEY`
- `PORT`
