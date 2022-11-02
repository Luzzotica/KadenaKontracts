# Airdrop Contract

To airdrop a specific coin or NFT there is a setup. 

Step One: Call `create-managed-account-from-k` with a name and a k: account. The contract will read the guard from the k: account you provide to it.
The name is the identifier you want to give to it. It will be used when airdropping.  
This is important and necessary because it makes the capabilities of airdropping much easier to manage.  

Step Two: For each coin or nft you wish to be able to airdrop, call `add-coin-to-managed-account` or `add-nft-to-managed-account` respectively.

Once those two steps are done, you are ready to airdrop things!  
Call the `airdrop-coin`, `split-coin`, or `airdrop-nft` functions to send the coin.