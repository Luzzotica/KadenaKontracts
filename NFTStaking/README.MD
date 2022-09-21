# Marmalade NFT Staker

Made by Sterling Long, please use with care.

The `marmalade-nft-staker` is a generic marmalade staking contract.
Once deployed, anyone can create a pool, with a payout token that lets people stake marmalade NFTs AS LONG AS the policy enables transferring.

## Assumptions

This contract assumes you have already created a marmalade NFT, and have the ID of that token. You will need the token id to create the pool wheree your users can stake the NFT.

## Process

1. Deploy the contract, include `init: true` in the data of the contract deployment.
2. Create a new pool using the `create-stakable-nft` function.
3. People can now stake and unstake their tokens and receive an APY for them.

## Notes

- The marmalade policy must allow token transfers
- Claim your tokens by unstaking
- Users can stake more than one of the same kind of NFT
- Users cannot stake additional NFTs if they already have some staked, they must unstake, and stake again

## Testing

To run the tests:
```
pact
(load "marmalade-nft-staker.repl")
```
