(namespace "free")

;; XX% APY, EQ: (1 + r/n)^n - 1, r is the annual interest rate, 
;; n is the compound intervals
;; (1 + r) - 1 = 0.15
;; To Calculate the total tokens made while staked we need:
;; Total Time Staked (TTS, seconds) = Current Time - Time Staked
;; APY = 0.15
;; Value of the NFT in whatever token you desire
;; Interest = TTS * APY * Value / 31536000 (SECONDS_IN_YEAR )
;; Token Value is in the Policy

(module marmalade-nft-staker GOV
  @doc "A contract that is used to stake marmalade NFTs. \
  \ Staking the NFT moves it into an escrow account using a pact. \
  \ Thus, the NFT policy must accept transferring the token, or this will fail."

  ;  (defconst APY:decimal 15.0)
  ;  (defconst COIN_POOL_GUARD:string "free.coin-pool-guard")
  ;  (defconst ESCROW_ACCOUNT:string "staking-escrow")
  ;  (defconst ESCROW_ACCOUNT_GUARD:string "free.staking-escrow-guard")
  ;  (use coin) ; fungible-v2
  ;  (use fungible-v2)

  (defcap GOV ()
    (enforce-guard (keyset-ref-guard GOV_KEYSET))
  )

  ;; -------------------------------
  ;; Constants

  (defconst GOV_KEYSET "free.staker-admin")

  (defconst SECONDS_IN_YEAR:integer 31536000)

  ;  (defconst APY_KEY:string "APY_KEY"
  ;    @doc "The key in the values table for the APY")
  ;  (defconst TOKEN_VALUE_KEY:string "TOKEN_VALUE_KEY"
  ;    @doc "The key in the values table for the token value")

  ;; -------------------------------
  ;; Schemas

  ;  (defschema value ;; ID is a const key value
  ;    @doc "Used to store decimal values, like APY"
  ;    value:decimal)

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
    ;  (compose-capability (marmalade.ledger.TRANSFER token-id account escrow-account amount))
    (compose-capability (ESCROW))
  )

  (defcap UNSTAKE 
    (
      account:string 
      escrow-account:string 
      guard:guard 
      token-id:string 
    )
    (enforce-guard guard)
    (compose-capability (ESCROW))
    (compose-capability (BANK))
    ;  (compose-capability (marmalade.ledger.TRANSFER token-id escrow-account account amount))
  )

  (defcap WITHDRAW (pool-name:string)
    @doc "Used to check if the individual can withdraw from the payout bank for the pool"
    (with-read stakable-nfts pool-name
      { "guard" := guard }
      (enforce-guard guard)
      (compose-capability (BANK))
    )
  )

  (defcap ESCROW ()
    @doc "Used to give permission to execute staking and unstaking functions"
    true
  )

  (defcap BANK ()
    @doc "Used to give permission to execute transfer functions from the bank"
    true
  )

  ;; -------------------------------
  ;; Stakable NFT Managing

  (defun create-stakable-nft 
    (
      pool-name:string
      token-id:string 
      payout-coin:module{fungible-v2} 
      payout-bank:string 
      escrow-account:string
      apy:decimal
      token-value:decimal
      lock-time-seconds:decimal
      guard:guard
    )
    @doc "Creates a stakable nft with necessary parameters. \
    \ Creates a bank account that is managed by the user guard."

    ; Create the bank account with the custom guard
    (payout-coin::create-account payout-bank (create-user-guard (bank-guard guard)))
    (marmalade.ledger.create-account token-id escrow-account (create-user-guard (escrow-guard)))

    ; Create the stakable nft record
    (insert stakable-nfts pool-name
      {
          "pool-name": pool-name
        , "token-id": token-id
        , "payout-coin": payout-coin
        , "payout-bank": payout-bank
        , "escrow-account": escrow-account
        , "apy": apy
        , "token-value": token-value
        , "lock-time-seconds": lock-time-seconds
        , "guard": guard
      }
    )
  )

  ;; -------------------------------
  ;; Basic Staking Functions

  ;  (defpact stake-unstake:string (account:string token-id:string amount:decimal)
  ;    @doc "Moves the AMOUNT of TOKEN-ID into an escrow account. \
  ;    \ APY begins accruing immediately."
    
  ;    (step 
  ;      ; Ensure the we have created a stakable nft for this
  ;      (read stakable-nfts (marmalade.ledger.key token-id account))
  ;      (with-capability (STAKE account token-id amount (pact-id))
  ;        (stake token-id amount)
  ;      )
  ;    )
  ;    (step
  ;      (with-capability (UNSTAKE account token-id amount (pact-id))
  ;        (unstake token-id amount)
  ;      )
  ;    )
  ;  )

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
      (install-capability (marmalade.ledger.TRANSFER token-id account escrow amount))

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

  (defun unstake:string (account:string pool-name:string token-id:string)
    @doc "Moves the given amount of token-id from escrow and claims the tokens"
    
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
        (enforce (> amount 0.0) "Cannot unstake if you have nothing staked")
        ; Ensure lock time has passed
        (let*
          (
            (stake-time-seconds (diff-time (curr-time) stake-start-time))
            (wait-time-seconds (- lock-time stake-time-seconds))
          )
          (enforce (> stake-time-seconds lock-time) (format "You must wait {} seconds before you can unstake" [wait-time-seconds]))
        )

        (with-capability (UNSTAKE account escrow guard token-id)
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
              (return (calculate-claimable-tokens 
                apy 
                (* token-value amount) 
                stake-start-time 
                (payout-coin::precision)))
            )
            
            ;  (install-capability (payout-coin::TRANSFER bank account return))
            (payout-coin::transfer-create bank account guard return)
            (format "Claimable: {}" [return])
          )
        )
      )
    )
  )

  (defun get-staked-for-pool:decimal (pool-name:string account:string)
    (at "amount" (read staked-nfts (key pool-name account)))
  )

  (defun get-current-apy:decimal (pool-name:string)
    (at "apy" (read stakable-nfts pool-name))
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

  (defun escrow-account:string ()
    @doc "Creates the escrow account that the token is transferred into"
    (create-principal (create-user-guard "ESCROW"))
  )

  (defun escrow-guard ()
    @doc "Generates a guard for the escrow account"
    (require-capability (ESCROW))
  )

  (defun bank-guard:bool (guard:guard)
    @doc "Creates the guard that is put on the payout account."
    (require-capability (BANK))
  )

  (defun withdraw-from-bank:string (pool-name:string receiver:string amount:decimal)
    @doc "Admin function that enables stakable NFT managers to withdraw from a payout account"
    (with-capability (WITHDRAW pool-name)
      (with-read stakable-nfts pool-name
        { "guard" := guard
        , "payout-bank" := payout-bank
        , "payout-coin" := payout-coin:module{fungible-v2} }
        
        (payout-coin::transfer-create payout-bank receiver guard amount)
        (format "Withdrew {} coins from {}" [amount payout-bank])
      )
    )
  )

  (defun key:string ( pool-name:string account:string )
    @doc "DB key for ledger account"
    (format "{}:{}" [pool-name account])
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