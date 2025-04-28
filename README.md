# Decentralized Content Subscription Platform

A Clarity smart contract for the Stacks blockchain that enables content creators to monetize their content through subscription-based models.

## Overview

This decentralized content subscription platform allows creators to:
- Register as content creators
- Create multiple subscription tiers with different pricing and benefits
- Earn STX tokens from subscriber payments

And enables users to:
- Subscribe to their favorite creators
- Choose from different subscription tiers
- Renew or cancel subscriptions

The platform takes a small fee from each subscription payment to sustain its operations.

## Features

- **Creator Profiles**: Content creators can register with a name and description
- **Subscription Tiers**: Creators can offer multiple subscription tiers with different benefits and pricing
- **Subscriptions**: Users can subscribe to creators for a specified duration
- **Renewals**: Users can renew existing subscriptions to extend access
- **Earnings Management**: Creators can claim their earnings at any time
- **Platform Administration**: Contract owner can manage platform fees and withdraw accumulated fees

## Smart Contract Functions

### Creator Functions

- `register-creator`: Register as a content creator
- `add-subscription-tier`: Create a new subscription tier
- `claim-earnings`: Withdraw available earnings

### Subscriber Functions

- `subscribe`: Subscribe to a creator's content tier
- `renew-subscription`: Extend an existing subscription
- `cancel-subscription`: Cancel an active subscription

### Admin Functions

- `withdraw-platform-fees`: Withdraw platform fees to the owner
- `set-platform-fee-percent`: Update the platform fee percentage
- `transfer-ownership`: Transfer contract ownership

### Read-Only Functions

- `get-creator-details`: Get creator profile information
- `get-creator-by-address`: Find creator ID by their address
- `get-tier-details`: Get subscription tier details
- `get-subscription`: Get subscription information
- `is-subscribed`: Check if a user is currently subscribed
- `get-platform-fee-percent`: Get current platform fee percentage
- `get-creator-count`: Get total number of registered creators

## Usage Examples

### Registering as a Creator

```clarity
(contract-call? .subscription-platform register-creator "Alice's Tech Blog" "Weekly tutorials on blockchain development")
```

### Creating a Subscription Tier

```clarity
(contract-call? .subscription-platform add-subscription-tier u1 "Premium" "Access to all content" u10000000 "Exclusive tutorials, early access, direct messaging")
```

### Subscribing to a Creator

```clarity
(contract-call? .subscription-platform subscribe u1 u1 u3) ;; Subscribe to creator 1, tier 1, for 3 months
```

## Platform Economics

- Platform fee: Initially set to 5% (configurable by admin)
- All subscription payments are processed in STX tokens
- Creators can withdraw their earnings at any time

## Development & Deployment

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) for local development and testing
- [Stacks wallet](https://hiro.so/wallet/install-web) for deploying to testnet/mainnet

### Local Testing

```bash
# Install dependencies
npm install

# Run tests
clarinet test

# Start local development chain
clarinet console
```

### Deployment

```bash
# Deploy to testnet
clarinet deploy --testnet

# Deploy to mainnet
clarinet deploy --mainnet
```

## License

MIT License