# DePay's EVM Web3 Payment Router.

## Deployments

Optimization Level: 800,000

### DePayRouterV2

Ethereum:
- [0xcbfc518FB621828fa6f0F4647D42931476ea473b](https://etherscan.io/address/0xcbfc518FB621828fa6f0F4647D42931476ea473b)

BNB Smart Chain:
- [0xAc68Ee6Bc43Bf075C0522a15E665547CFd28628D](https://bscscan.com/address/0xAc68Ee6Bc43Bf075C0522a15E665547CFd28628D)

Polygon (POS):
- [0x1eD1e2dEEEa8B5C802663780284eDa63f62A3825](https://polygonscan.com/address/0x1eD1e2dEEEa8B5C802663780284eDa63f62A3825)

Avalanche:
- [0x8B127D169D232D5F3ebE1C3D06CE343FD7C1AA11](https://snowtrace.io/address/0x8B127D169D232D5F3ebE1C3D06CE343FD7C1AA11)

Fantom:
- [0x8B127D169D232D5F3ebE1C3D06CE343FD7C1AA11](https://ftmscan.com/address/0x8B127D169D232D5F3ebE1C3D06CE343FD7C1AA11)

Gnosis:
- [0x8B127D169D232D5F3ebE1C3D06CE343FD7C1AA11](https://gnosisscan.io/address/0x8B127D169D232D5F3ebE1C3D06CE343FD7C1AA11)

Optimism:
- [0x8B127D169D232D5F3ebE1C3D06CE343FD7C1AA11](https://optimistic.etherscan.io/address/0x8B127D169D232D5F3ebE1C3D06CE343FD7C1AA11)

Arbitrum:
- [0x8B127D169D232D5F3ebE1C3D06CE343FD7C1AA11](https://arbiscan.io/address/0x8B127D169D232D5F3ebE1C3D06CE343FD7C1AA11)

Base:
- [0xfAD2F276D464EAdB71435127BA2c2e9dDefb93a4](https://basescan.org/address/0xfAD2F276D464EAdB71435127BA2c2e9dDefb93a4)

### DePayForwarderV2

Ethereum:
- [0x41d1642C3818c56E8B37Df4DDe8931E25817C056](https://etherscan.io/address/0x41d1642C3818c56E8B37Df4DDe8931E25817C056)

BNB Smart Chain:
- [0xCc62775fB6925632273630f81e32D134C9049751](https://bscscan.com/address/0xCc62775fB6925632273630f81e32D134C9049751)

Polygon (POS):
- [0x31D5e0E63A9913e97e3cFdD651C8ABd47af799F1](https://polygonscan.com/address/0x31D5e0E63A9913e97e3cFdD651C8ABd47af799F1)

Avalanche:
- [0xEE3fedC6b2A81636753e70c982A16eBA3CB836a4](https://snowtrace.io/address/0xEE3fedC6b2A81636753e70c982A16eBA3CB836a4)

Fantom:
- [0xfAD2F276D464EAdB71435127BA2c2e9dDefb93a4](https://ftmscan.com/address/0xfAD2F276D464EAdB71435127BA2c2e9dDefb93a4)

Gnosis:
- [0xEE3fedC6b2A81636753e70c982A16eBA3CB836a4](https://gnosisscan.io/address/0xEE3fedC6b2A81636753e70c982A16eBA3CB836a4)

Optimism: 
- [0xEE3fedC6b2A81636753e70c982A16eBA3CB836a4](https://optimistic.etherscan.io/address/0xEE3fedC6b2A81636753e70c982A16eBA3CB836a4)

Arbitrum:
- [0xEE3fedC6b2A81636753e70c982A16eBA3CB836a4](https://arbiscan.io/address/0xEE3fedC6b2A81636753e70c982A16eBA3CB836a4)

Base:
- [0x5EC3153BACebb5e49136cF2d457f26f5Df1B6780](https://basescan.org/address/0x5EC3153BACebb5e49136cF2d457f26f5Df1B6780)

## Summary

This smart contract enables decentralized payments with auto-conversion and payment-fee extraction.

The main purpose of this smart contract evolves around the `pay` function.

This smart contract allows for NATIVE to NATIVE, NATIVE to TOKEN, TOKEN to NATIVE, WRAPPED to NATIVE, NATIVE to WRAPPED and TOKEN_A to TOKEN_B payments.

#### Transfer polyfil

The `DePayRouterV2` emits a `InternalTransfer` event for payments where the receiver token is the native token of the respective chain (e.g. Ether on Ethereum).

This allows to validate native token transfers without checking for internal transfers, but instead rely on `InternalTransfer` events, similiar to Token `Transfer` events.

Standard tokens (e.g. ERC20 etc.) already do emit `Transfer` events as part of their standard.

## Development

Create an `.env` file with the following content:
```
NODE_ENV=development

MNEMONIC="shine romance erase resource daring bean talk right cupboard visa renew galaxy"
#(0) 0xdde3dc4308A7856D49D1d7303bB630Bccb45Caf9
#(1) 0x26Fe22F655303151C2ef3b2D097F842ab27Ef940
#(2) 0x877a79C20028F9ef81e956B43B917703cC22A07A
#(3) 0x3a36b51c5125A9c064f4Cd2F492989618CF7660E

ARBITRUM_NOVA_RPC_URL=https://arbitrum-nova.blastapi.io/<APIKEY>
ARBITRUM_ONE_RPC_URL=https://arbitrum-one.blastapi.io/<APIKEY>
AVALANCHE_RPC_URL=https://ava-mainnet.blastapi.io/<APIKEY>/ext/bc/C/rpc
BSC_RPC_URL=https://bsc-mainnet.blastapi.io/<APIKEY>
ETHEREUM_RPC_URL=https://eth-mainnet.blastapi.io/<APIKEY>
FANTOM_RPC_URL=https://fantom-mainnet.blastapi.io/<APIKEY>
GNOSIS_RPC_URL=https://gnosis-mainnet.blastapi.io/<APIKEY>
OPTIMISM_RPC_URL=https://optimism.blockpi.network/v1/rpc/public
POLYGON_RPC_URL=https://polygon-mainnet.blastapi.io/<APIKEY>
POLYGON_ZKEVM_RPC_URL=https://polygon-zkevm-mainnet.blastapi.io/<APIKEY>
ZKSYNC_ERA_RPC_URL=https://mainnet.era.zksync.io
```

### Quick Start

```
yarn install
yarn test
```

### Testing

Test on a specific chain:
```
yarn test:<chain>
```

e.g. `ethereum`, `bsc` etc.

Test on all blockchains:

```
yarn test
```

Test single files:

```
npx hardhat test test/bsc/pay_with_exchange_conversion.spec.ts --config hardhat.config.bsc.ts
```

### Deploy

1. `yarn flatten`

2. Deploy flatten contract

