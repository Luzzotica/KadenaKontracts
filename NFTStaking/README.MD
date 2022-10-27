# Marmalade NFT Staking

The `marmalade-nft-staking` contract is used to stake specific marmalade NFTs.
It is controlled by a GOV and OPS keyset.
The OPS keyset can be rotated, the GOV cannot. Don't lose that keyset.

## Assumptions

This contract assumes you have already created a marmalade NFT, and have the ID of that token. You will need the token id to create the pool where your users can stake the NFT.

## Process

1. Deploy the contract. You must include `init: true` and `ops: <YOUR_KEYSET>` in the data of the contract deployment.
2. Create a new pool using the `create-unlocked-nft-pool` or `create-locked-nft-pool` functions.
3. People can now stake and unstake their tokens and receive an APY for them.

## Notes

- The marmalade policy must allow token transfers
- Call the `claim` function to claim tokens
- Staking more or unstaking will call the `claim` function
- If you wish to deactivate a pool, you can set it to INACTIVE using the `set-pool-status` function.

## Testing

To run the tests:
```
pact
(load "marmalade-nft-staking.repl")
```
