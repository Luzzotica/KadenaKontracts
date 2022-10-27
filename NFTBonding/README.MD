# Marmalade NFT Bonding

The `marmalade-nft-bonding` contract is used to provide maturity to an NFT after a provided period of time.
It is controlled by a GOV and OPS keyset.
The OPS keyset can be rotated, the GOV cannot. Don't lose that keyset.

## Assumptions

This contract assumes you have already created a marmalade NFT, and have the ID of that token. You will need the token id to create the pool that will eventually mature.

## Process

1. Deploy the contract. You must include `init: true` and `ops: <YOUR_KEYSET>` in the data of the contract deployment.
2. Create a new pool using the `create-bonded-nft` function.
3. People can now claim their tokens once the bond matures.
4. Bonded NFTs are stored in an escrow after claim.

## Notes

- The marmalade policy must allow token transfers
- Call the `claim` function to claim tokens after maturity
- Staking more or unstaking will call the `claim` function
- If you wish to cancel a bond, you can set it to CANCELED using the `set-pool-status` function.

## Testing

To run the tests:
```
pact
(load "marmalade-nft-bonding.repl")
```
