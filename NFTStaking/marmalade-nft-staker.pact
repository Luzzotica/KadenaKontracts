(namespace "free")

(module marmalade-nft-staker GOV
  @doc "A contract that is used to stake marmalade NFTs. \
  \ Staking the NFT moves it into an escrow account using a pact. \
  \ Thus, the NFT policy must accept transferring the token, or this will fail."

  (defcap GOV ()
    (enforce-keyset GOV_KEYSET)
  )

  ;; -------------------------------
  ;; Constants

  (defconst GOV_KEYSET "free.staker-admin")

  (defconst SECONDS_IN_YEAR:integer 31536000)

  ;; -------------------------------
  ;; Schemas

  (defschema stakable-nft ;; ID is the pool-name
    pool-name:string
    token-id:string
    payout-coin:module{fungible-v2}
    payout-bank:string
    escrow-account:string
    apy:decimal
    token-value:decimal
    lock-time-seconds:decimal
    guard:guard ;; Will be combined with claim capability and applied to the bank
  )

  (defschema staked-nft ;; ID is pool-name:account
    @doc "Stores the NFTs that have been staked and transferred into the escrow"
    account:string
    pool-name:string
    token-id:string
    guard:guard
    amount:decimal
    stake-start-time:time)
  
  ;  (deftable values:{value})
  (deftable stakable-nfts:{stakable-nft})
  (deftable staked-nfts:{staked-nft})

  ;; -------------------------------
  ;; Basic Staking Functions

  (defcap PRIVATE ()
    true
  )

  (defcap STAKE (account:string escrow-account:string token-id:string amount:decimal)
    true
  )

  (defcap UNSTAKE 
    (
      guard:guard
    )
    (enforce-guard guard)
  )

  (defcap WITHDRAW (pool-name:string)
    @doc "Used to check if the individual can withdraw from the payout bank for the pool"
    (with-read stakable-nfts pool-name
      { "guard" := guard }
      (enforce-guard guard)
    )
  )

  ;  (defcap ESCROW ()
  ;    @doc "Used to give permission to execute staking and unstaking functions"
  ;    true
  ;  )

  ;  (defcap BANK ()
  ;    @doc "Used to give permission to execute transfer functions from the bank"
  ;    true
  ;  )

  ;; -------------------------------
  ;; Stakable NFT Managing

  (defun create-stakable-nft:string 
    (
      pool-name:string
      token-id:string 
      payout-coin:module{fungible-v2}
      apy:decimal
      token-value:decimal
      lock-time-seconds:decimal
      guard:guard
    )
    @doc "Creates a stakable nft with necessary parameters. \
    \ Creates a bank account that is managed by the user guard."

    ; Create the bank account with the pool module guard
    (let
      (
        (p-guard (pool-guard pool-name))
        (account-name (pool-account-name pool-name))
      )

      (payout-coin::create-account account-name p-guard)
      (marmalade.ledger.create-account token-id account-name p-guard)

      ; Create the stakable nft record
      (insert stakable-nfts pool-name
        {
            "pool-name": pool-name
          , "token-id": token-id
          , "payout-coin": payout-coin
          , "payout-bank": account-name
          , "escrow-account": account-name
          , "apy": apy
          , "token-value": token-value
          , "lock-time-seconds": lock-time-seconds
          , "guard": guard
        }
      )
    )

    
  )

  ;; -------------------------------
  ;; Basic Staking Functions

  (defun stake:string 
    (
      account:string 
      guard:guard 
      pool-name:string 
      token-id:string 
      amount:decimal
    )
    @doc "Moves the given amount of token-id into escrow to start earning APY"
    
    (with-read stakable-nfts pool-name
      { "escrow-account" := escrow }
      ; Install the transfer capability
      ;  (install-capability (marmalade.ledger.TRANSFER token-id account escrow amount))

      (with-capability (STAKE account escrow token-id amount)
        (with-default-read staked-nfts (key pool-name account)
          { 
            "account": account
            , "pool-name": pool-name
            , "token-id": token-id
            , "guard": guard
            , "amount": -1.0
            , "stake-start-time": (curr-time)
          }
          {
            "amount" := curr-amount
          }

          ; Stop people from staking more tokens if some are already there
          (enforce (<= curr-amount 0.0) "Cannot stake tokens if some are already there")

          ; Transfer the token amount to the escrow
          (marmalade.ledger.transfer token-id account escrow amount) 

          ; Insert info into staked balance
          (write staked-nfts (key pool-name account)
            { 
              "account": account
              , "pool-name": pool-name
              , "token-id": token-id
              , "guard": guard
              , "amount": amount
              , "stake-start-time": (curr-time)
            }
          )
        )
      )
    )
  )

  (defun unstake:decimal (account:string pool-name:string token-id:string)
    @doc "Moves the given amount of token-id from escrow and claims the tokens. \
    \ Returns the number of tokens claimed from the unstake action."
    
    (with-read stakable-nfts pool-name
      { "escrow-account" := escrow
      , "apy" := apy
      , "token-value" := token-value
      , "payout-bank" := bank
      , "payout-coin" := payout-coin:module{fungible-v2}
      , "lock-time-seconds" := lock-time }
      
      (with-read staked-nfts (key pool-name account)
        { "guard" := guard
        , "amount" := amount
        , "stake-start-time" := stake-start-time }

        (with-capability (UNSTAKE guard)
          (enforce (> amount 0.0) "Cannot unstake if you have nothing staked")
          ; Ensure lock time has passed
          (let*
            (
              (stake-time-seconds:decimal (diff-time (curr-time) stake-start-time))
              (wait-time-seconds:decimal (- lock-time stake-time-seconds))
            )
            ;  (wait-time-seconds-str:string (int-to-str 10 (ceiling wait-time-seconds)))
            (enforce (> stake-time-seconds lock-time) 
              ;  (concat ["You must wait " wait-time-seconds-str " seconds before you can unstake"])
              (format "You must wait {} seconds before you can unstake" [wait-time-seconds])
            )
          )

          ; Transfer NFTs out of escrow
          (install-capability (marmalade.ledger.TRANSFER token-id escrow account amount))
          (marmalade.ledger.transfer token-id escrow account amount) 

          ; Update staked nfts info
          (update staked-nfts (key pool-name account)
            { "amount": 0.0 }
          )

          ; Claim the generated tokens
          (let 
            (
              (return:decimal (calculate-claimable-tokens 
                apy 
                (* token-value amount) 
                stake-start-time 
                (payout-coin::precision)))
            )
            
            (install-capability (payout-coin::TRANSFER bank account return))
            (payout-coin::transfer-create bank account guard return)
            ;  (concat ["Unstake claimed " (decimal-to-str return) " tokens"])
            ;  (format "Unstake claimed {} tokens" [return])
            return
          )
        )
      )
    )
  )

  (defun get-staked-for-pool:decimal (pool-name:string account:string)
    (at "amount" (read staked-nfts (key pool-name account) ["amount"]))
  )

  (defun get-current-apy:decimal (pool-name:string)
    (at "apy" (read stakable-nfts pool-name ["apy"]))
  )

  (defun get-bank-for-pool:string (pool-name:string)
    (at "payout-bank" (read stakable-nfts pool-name ["payout-bank"]))
  )

  (defun get-escrow-for-pool:string (pool-name:string)
    (at "escrow-account" (read stakable-nfts pool-name ["escrow-account"]))
  )

  (defun get-claimable-tokens:decimal (pool-name:string account:string)
    @doc "Gets the tokens earned for this account in the given pool"
    (with-read stakable-nfts pool-name
      { "apy" := apy
      , "token-value" := value
      , "payout-coin" := payout-coin:module{fungible-v2} }  
      (with-read staked-nfts (key pool-name account)
        { "amount" := amount
        , "stake-start-time" := stake-start-time }
        (calculate-claimable-tokens apy (* value amount) stake-start-time (payout-coin::precision))
      )
    )
  )

  ;; -------------------------------
  ;; Utils

  (defun calculate-claimable-tokens:decimal
    (
      apy:decimal 
      value:decimal 
      stake-start-time:time
      precision:integer
    )
    @doc "Interest = Total Time Staked * APY * Value / 31536000 (SECONDS_IN_YEAR )"
    (round (/ (* (* value (diff-time (curr-time) stake-start-time)) apy) SECONDS_IN_YEAR) precision)
  )

  (defun pool-guard:guard (pool-name:string)
    @doc "Creates a guard that is used for both the bank and escrow accounts for the pool"
    (create-module-guard pool-name)
  )

  (defun pool-account-name:string (pool-name:string)
    (create-principal (pool-guard pool-name))
  )
  
  (defun withdraw-from-bank:string (pool-name:string receiver:string amount:decimal)
    @doc "Admin function that enables stakable NFT managers to withdraw from a payout account"
    (with-capability (WITHDRAW pool-name)
      (with-read stakable-nfts pool-name
        { "guard" := guard
        , "payout-bank" := payout-bank
        , "payout-coin" := payout-coin:module{fungible-v2} }
        
        (install-capability (payout-coin::TRANSFER payout-bank receiver amount))
        (payout-coin::transfer-create payout-bank receiver guard amount)
        ;  (concat ["Withdrew " (int-to-str 10 (floor amount)) " coins (Rounded down) from " payout-bank])
        (format "Withdrew {} coins from {}" [amount payout-bank])
      )
    )
  )

  (defun key:string ( pool-name:string account:string )
    @doc "DB key for ledger account"
    (concat [pool-name ":" account])
  )

  (defun curr-time:time ()
    @doc "Returns current chain's block-time in time type"

    (at 'block-time (chain-data))
  )
)

(if (read-msg "init")
  [(create-table free.marmalade-nft-staker.stakable-nfts)
    (create-table free.marmalade-nft-staker.staked-nfts)]
    "No init")