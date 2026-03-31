# Sukuk Smart Contract

A Clarity smart contract implementing Islamic bonds (Sukuk) on the Stacks blockchain.

## Overview

This smart contract enables the issuance and management of Sukuk (Islamic bonds) with the following features:

- **Sukuk Issuance**: Government issuer can configure sukuk parameters
- **Public Subscription**: Investors can subscribe by sending STX
- **Maturity Management**: Time-based maturity checking
- **Profit Distribution**: 5% profit on principal at maturity
- **Redemption**: Investors can redeem their sukuk after maturity

## Contract Features

### Data Variables
- `issuer`: The government issuer address
- `sukuk-name`: Name of the sukuk fund
- `sukuk-symbol`: Symbol for the sukuk
- `sukuk-total-supply`: Total sukuk to be issued
- `sukuk-price`: Price per sukuk unit (1 STX = 1,000,000 micro-STX)
- `sukuk-maturity`: Maturity block height
- `total-subscribed`: Total STX collected from subscriptions

### Public Functions

#### `configure-sukuk`
```clarity
(configure-sukuk (maturity-block-height uint) (total-supply uint))
```
- Only callable by the issuer
- Sets the maturity block height and total supply
- Can only be called once

#### `subscribe-sukuk`
```clarity
(subscribe-sukuk)
```
- Allows investors to subscribe by sending STX
- Transfers STX to the contract
- Records subscription details

#### `redeem`
```clarity
(redeem)
```
- Allows investors to redeem after maturity
- Returns principal + 5% profit
- Clears the subscription record

### Read-Only Functions

#### `is-matured`
```clarity
(is-matured)
```
- Checks if the sukuk has reached maturity

#### `get-subscriber`
```clarity
(get-subscriber (acct principal))
```
- Returns subscription details for an account

#### `get-total-subscribed`
```clarity
(get-total-subscribed)
```
- Returns total STX collected

#### `get-terms`
```clarity
(get-terms)
```
- Returns sukuk terms (name, symbol, price, maturity)

## Error Codes

- `ERR_NOT_ISSUER` (u100): Only issuer can perform this action
- `ERR_INSUFFICIENT_PAYMENT` (u101): Insufficient STX payment
- `ERR_NO_SUBSCRIPTION` (u102): No subscription found
- `ERR_NOT_MATURED` (u103): Sukuk has not matured yet
- `ERR_ALREADY_SET_MATURITY` (u104): Maturity already configured

## Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- Node.js (for tests)

### Testing
```bash
# Check contract syntax
clarinet check

# Run interactive console
clarinet console

# Install dependencies and run tests
npm install
npm test
```

### Example Usage

1. **Configure Sukuk** (Issuer only):
```clarity
(contract-call? .sukuk_smart configure-sukuk u1000 u10000000)
```

2. **Subscribe to Sukuk**:
```clarity
(contract-call? .sukuk_smart subscribe-sukuk)
```

3. **Check Maturity**:
```clarity
(contract-call? .sukuk_smart is-matured)
```

4. **Redeem After Maturity**:
```clarity
(contract-call? .sukuk_smart redeem)
```

## Contract Status

✅ **Debugged and Validated**
- All Clarinet checks pass
- Syntax errors fixed
- Error handling implemented
- Tested in Clarinet console

## License

MIT License
