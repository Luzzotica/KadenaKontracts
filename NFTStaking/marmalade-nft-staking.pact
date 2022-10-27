(namespace "free")

(module marmalade-nft-staking GOV
  @doc "A contract that is used to stake marmalade NFTs. \
  \ Staking the NFT moves it into an escrow account using a pact. \
  \ Thus, the NFT policy must accept transferring the token, or this will fail."

  (defcap GOV ()
    (enforce-guard (at "guard" (read m-guards GOV_GUARD ["guard"])))
  )

  ;; -------------------------------
  ;; Constants

  (defconst SECONDS_IN_YEAR:decimal 31536000.0)

  (defconst STATUS_ACTIVE:string "ACTIVE"
    @doc "Active means you can stake to the pool.")
  (defconst STATUS_INACTIVE:string "INACTIVE"
    @doc "Inactive means you cannot stake to the pool, and you cannot claim tokens from the pool.")
  
  (defconst GOV_GUARD:string "gov")
  (defconst OPS_GUARD:string "ops")

  ;; -------------------------------
  ;; Schemas

  (defschema m-guard ;; ID is a const: OPS_GUARD, etc.
    @doc "Stores guards for the module"
    guard:guard  
  )

  (defschema nft-pool ;; ID is the pool-name
    pool-name:string
    token-id:string
    payout-coin:module{fungible-v2}
    payout-bank:string
    escrow-account:string
    token-value:decimal
    apy:decimal
    status:string
    start-time:time
    is-locked-pool:bool
    lock-time-seconds:decimal
    lock-bonus:decimal
  )

  (defschema staked-nft ;; ID is pool-name:account
    @doc "Tracks the NFTs that have been staked and transferred into the escrow"
    account:string
    pool-name:string
    guard:guard
    amount:decimal
    stake-start-time:time
    bonus:decimal
  )
  
  (deftable m-guards:{m-guard})
  (deftable nft-pools:{nft-pool})
  (deftable staked-nfts:{staked-nft})

  ;; -------------------------------
  ;; Capabilities

  (defcap OPS ()
    (enforce-guard (at "guard" (read m-guards OPS_GUARD ["guard"])))
    (compose-capability (WITHDRAW))
  )

  (defcap WITHDRAW ()
    @doc "Used to give permission to withdraw money from the bank"
    true
  )

  (defcap STAKE (pool-name:string account:string amount:decimal)
    (compose-capability (CLAIM pool-name account))
  )

  (defcap UNSTAKE (pool-name:string account:string amount:decimal)
    (compose-capability (CLAIM pool-name account))
  )

  (defcap CLAIM (pool-name:string account:string)
    (with-read staked-nfts (key pool-name account)
      { "guard" := guard }
      (enforce-guard guard)
    )
    (compose-capability (WITHDRAW))
  )

  ;; -------------------------------
  ;; Stakable NFT Managing

  (defun create-unlocked-nft-pool:string 
    (
      pool-name:string
      token-id:string 
      payout-coin:module{fungible-v2}
      apy:decimal
      token-value:decimal
      start-time:time
    )
    @doc "Creates a stakable nft with necessary parameters. \
    \ Creates a bank account that is managed by the user guard. \
    \ Cannot stake into the pool until after the given start time."

    (with-capability (OPS)
      (create-nft-pool 
        pool-name
        token-id
        payout-coin
        apy
        token-value
        start-time ; Origin of time: 1970
        false ; Not a locked pool
        0.0 ; No lock time
        0.0) ; No bonus
    )
  )

  (defun create-locked-nft-pool:string 
    (
      pool-name:string
      token-id:string 
      payout-coin:module{fungible-v2}
      apy:decimal
      token-value:decimal
      start-time:time
      lock-time-seconds:decimal
      bonus:decimal
    )
    @doc "Creates a locked nft pool. \
    \ Locked NFT pools go into effect at a specific date and unlock after a period of time. \
    \ NFTs can be staked/unstaked freely before the start date, but the pool is frozen after that time. \
    \ A bonus can be provided which is made claimable to the stakers after the start date."

    (enforce (>= bonus 0.0) "Lock bonus must be greater than or equal to 0")
    (enforce (>= lock-time-seconds 0.0) "Lock time must be greater than or equal to 0")
    ;  (enforce (not (pool-is-locked start-time lock-time-seconds)) "Start time after right the fetch now")

    (with-capability (OPS)
      (create-nft-pool 
        pool-name
        token-id
        payout-coin
        apy
        token-value
        start-time
        true
        lock-time-seconds
        bonus)
    )
  )

  (defun create-nft-pool:string 
    (
      pool-name:string
      token-id:string 
      payout-coin:module{fungible-v2}
      apy:decimal
      token-value:decimal
      start-time:time
      is-locked-pool:bool
      lock-time-seconds:decimal
      lock-bonus:decimal
    )
    @doc "Private function used to create an NFT pool"
    
    (require-capability (OPS))

    (enforce (> token-value 0.0) "Value must be greater than 0")
    (enforce (> apy 0.0) "APY must be greater than 0")

    ; Create the bank account with the pool module guard
    (let
      (
        (account-name (pool-account-name pool-name))
        (p-guard (pool-guard pool-name))
      )

      (payout-coin::create-account account-name p-guard)
      (marmalade.ledger.create-account token-id account-name p-guard)

      ; Create the stakable nft record
      (insert nft-pools pool-name
        { "pool-name": pool-name
        , "token-id": token-id
        , "payout-coin": payout-coin
        , "payout-bank": account-name
        , "escrow-account": account-name
        , "token-value": token-value
        , "apy": apy
        , "status": STATUS_ACTIVE
        , "is-locked-pool": is-locked-pool
        , "start-time": start-time
        , "lock-time-seconds": lock-time-seconds
        , "lock-bonus": lock-bonus
        }
      )
    )
  )

  ;; -------------------------------
  ;; Basic Staking Functions

  (defun stake:string 
    (
      pool-name:string 
      account:string 
      amount:decimal
      guard:guard 
    )
    @doc "Moves the given amount of marmalade tokens into escrow to start earning APY \
    \ Claims tokens if tokens have already been staked."
    
    (enforce (> amount 0.0) "Amount must be positive")

    (with-read nft-pools pool-name
      { "escrow-account" := escrow
      , "apy" := apy
      , "token-id" := token-id
      , "token-value" := token-value
      , "payout-bank" := bank
      , "payout-coin" := payout-coin:module{fungible-v2}
      , "status" := status
      , "start-time" := start-time
      , "is-locked-pool" := is-locked-pool
      , "lock-time-seconds" := lock-time-seconds
      , "lock-bonus" := lock-bonus
      }

      (enforce (= status STATUS_ACTIVE) "Cannot stake into an inactive pool")

      ;; Enforce locked pool params
      (if is-locked-pool
        (enforce (< (curr-time) start-time) "Can't stake into a locked pool that has started or ended")
        []
      )

      (with-default-read staked-nfts (key pool-name account)
        { "account": account
        , "pool-name": pool-name
        , "guard": guard
        , "amount": -1.0
        , "stake-start-time": (if (or is-locked-pool (> start-time (curr-time))) ; If it is a locked pool, or the start time was before NOW 
            start-time ; start earning when the pool starts
            (curr-time) ; Otherwise, start earning immediately
          ) 
        , "bonus": lock-bonus
        }
        { "amount" := curr-amount
        , "bonus" := bonus
        , "stake-start-time" := stake-start-time
        }
        
        ; No stake record: Insert info into staked balance if no staked record was found
        (if (= curr-amount -1.0)
          (insert staked-nfts (key pool-name account)
            { "account": account
            , "pool-name": pool-name
            , "guard": guard
            , "amount": amount
            , "stake-start-time": stake-start-time
            , "bonus": bonus
            }
          )
          (with-capability (STAKE pool-name account amount) ; Otherwise, handle claiming and amount update

            ; If we have tokens already staked, claim the interest to reset with the new token count
            (if (> curr-amount 0.0)
              (internal-claim 
                pool-name
                status
                account 
                bank
                payout-coin
                token-value 
                apy 
                curr-amount
                stake-start-time 
                bonus
                guard
              )
              []
            )

            ; Update the amount staked, current time is handled by claim, or by insert
            (update staked-nfts (key pool-name account)
              { "amount": (+ curr-amount amount) }
            )
          )
        )

        ; Transfer the token amount to the escrow
        (marmalade.ledger.transfer token-id account escrow amount) 
      )
    )
  )

  (defun unstake:decimal 
    (
      pool-name:string 
      account:string 
      amount:decimal
    )
    @doc "Moves the given amount of marmalade tokens from escrow. \
    \ Claims the accrued interest and resets them to 0. \
    \ Returns the amount of interest claimed."
    
    (with-capability (UNSTAKE pool-name account amount)

      (with-read nft-pools pool-name
        { "escrow-account" := escrow
        , "apy" := apy
        , "token-id" := token-id
        , "token-value" := token-value
        , "payout-bank" := bank
        , "payout-coin" := payout-coin:module{fungible-v2}
        , "is-locked-pool" := is-locked-pool
        , "start-time" := start-time
        , "lock-time-seconds" := lock-time
        , "status" := status
        }

        ; If we are a locked pool, fail to unstake while the pool is locked
        (if 
          (and is-locked-pool (pool-is-locked start-time lock-time))
          (enforce false "Cannot unstake from a locked pool that has started")
          []
        )
        
        (with-read staked-nfts (key pool-name account)
          { "guard" := guard
          , "amount" := curr-amount
          , "stake-start-time" := stake-start-time
          , "bonus" := bonus
          }

          (enforce (> amount 0.0) "Must unstake more than 0.0")
          (enforce (<= amount curr-amount) "Cannot unstake more tokens than you have")

          ; Transfer NFTs out of escrow
          (install-capability (marmalade.ledger.TRANSFER token-id escrow account amount))
          (marmalade.ledger.transfer token-id escrow account amount) 

          ; Claim tokens
          (internal-claim 
            pool-name
            status
            account 
            bank
            payout-coin
            token-value 
            apy 
            curr-amount
            stake-start-time 
            bonus
            guard
          )

          ; Update staked nfts info
          (update staked-nfts (key pool-name account)
            { "amount": (- curr-amount amount) }
          )
        )
      )
    )
  )

  (defun claim:string (pool-name:string account:string)
    @doc "Claims the available tokens from a pool and resets stake time to current time."
    (with-capability (CLAIM pool-name account)
      (with-read nft-pools pool-name
        { "apy" := apy
        , "token-id" := token-id
        , "token-value" := token-value
        , "payout-bank" := bank
        , "payout-coin" := payout-coin:module{fungible-v2}
        , "status" := status
        }

        (enforce (= status STATUS_ACTIVE) "Can't claim from an inactive pool")
        
        (with-read staked-nfts (key pool-name account)
          { "guard" := guard
          , "amount" := amount
          , "stake-start-time" := stake-start-time
          , "bonus" := bonus
          }
          
          (internal-claim 
            pool-name
            status
            account 
            bank
            payout-coin
            token-value 
            apy 
            amount
            stake-start-time 
            bonus
            guard
          )
        )
      )
    )
  )

  (defun internal-claim:string 
    (
      pool-name:string 
      status:string
      account:string 
      bank:string
      payout-coin:module{fungible-v2}
      token-value:decimal
      apy:decimal
      amount:decimal
      stake-start-time:time
      bonus:decimal
      guard:guard
    )
    @doc "Only callable from a private context. \
    \ Claims the available tokens from a pool and resets stake time to current time."
    
    (require-capability (CLAIM pool-name account))

    ; If the curr time is greater than the stake start time, we have tokens 
    ; that can be claimed.
    (if (is-claimable stake-start-time status)
      (let
        (
          (amount:decimal (+ bonus (calculate-claimable-tokens 
            apy 
            (* token-value amount) 
            stake-start-time 
            (payout-coin::precision))))
        )
        
        (install-capability (payout-coin::TRANSFER bank account amount))
        (payout-coin::transfer-create bank account guard amount)

        (update staked-nfts (key pool-name account)
          { "stake-start-time": (curr-time)
          , "bonus": 0.0 
          }
        ) 
        
        (format "Claimed {} tokens." [(round amount 2)])
      )
      "Nothing claimed"
    )
  )

  ;; -------------------------------
  ;; Getters and Setters

  (defun get-pools:[object{nft-pool}] ()
    (select nft-pools (where "pool-name" (!= "")))
  )

  (defun get-active-pools:[object{nft-pool}] ()
    (select nft-pools (where "status" (= STATUS_ACTIVE)))
  )

  (defun get-pool-details:object{nft-pool} (pool-name:string)
    (read nft-pools pool-name)
  )

  (defun get-staked-nfts-for-account:[object{staked-nft}] (account:string)
    (select staked-nfts (where "account" (= account)))
  )

  (defun get-staked-for-pool:decimal (pool-name:string account:string)
    (at "amount" (read staked-nfts (key pool-name account) ["amount"]))
  )

  (defun get-start-time-for-pool:time (pool-name:string account:string)
    (at "stake-start-time" (read staked-nfts (key pool-name account) ["stake-start-time"]))
  )

  (defun get-pool-token-id:string (pool-name:string)
    (at "token-id" (read nft-pools pool-name ["token-id"]))
  )

  (defun get-pool-apy:decimal (pool-name:string)
    (at "apy" (read nft-pools pool-name ["apy"]))
  )

  (defun get-pool-bank:string (pool-name:string)
    (at "payout-bank" (read nft-pools pool-name ["payout-bank"]))
  )

  (defun get-pool-escrow:string (pool-name:string)
    (at "escrow-account" (read nft-pools pool-name ["escrow-account"]))
  )

  (defun get-pool-status:string (pool-name:string)
    (at "status" (read nft-pools pool-name ["status"]))
  )

  (defun get-pool-start-time:time (pool-name:string)
    (at "start-time" (read nft-pools pool-name ["start-time"]))
  )

  (defun get-pool-lock-time:decimal (pool-name:string)
    (at "lock-time-seconds" (read nft-pools pool-name ["lock-time-seconds"]))
  )

  (defun get-pool-lock-bonus:decimal (pool-name:string)
    (at "lock-bonus" (read nft-pools pool-name ["lock-bonus"]))
  )

  (defun get-pool-is-locked-pool:decimal (pool-name:string)
    (at "is-locked-pool" (read nft-pools pool-name ["is-locked-pool"]))
  )

  (defun get-claimable-tokens:decimal (pool-name:string account:string)
    @doc "Gets the tokens earned for this account in the given pool"
    (with-read nft-pools pool-name
      { "apy" := apy
      , "token-value" := value
      , "payout-coin" := payout-coin:module{fungible-v2} 
      , "status" := status
      }  
      (with-read staked-nfts (key pool-name account)
        { "amount" := amount
        , "stake-start-time" := stake-start-time
        , "bonus" := bonus
        }
        ; If the stake start time is greater than the current time, we have tokens 
        ; that can be claimed.
        (if (is-claimable stake-start-time status)
          (+ 
            bonus 
            (calculate-claimable-tokens 
              apy (* value amount) stake-start-time (payout-coin::precision)))
          0.0 ; Otherwise, return 0.0, no tokens to claim
        )
      )
    )
  )

  (defun set-pool-status:string (pool-name:string status:string)
    @doc "Requires OPS. Sets the status of the pool to the provided one."

    (with-capability (OPS)
      (enforce (or (= status STATUS_ACTIVE) (= status STATUS_INACTIVE)) "Status must be ACTIVE or CANCELED")

      (update nft-pools pool-name
        { "status": status }
      )

      (concat ["Pool status updated to: " status])
    )
  )

  (defun rotate-ops:string (guard:guard)
    @doc "Requires OPS. Changes the ops guard to the provided one."

    (with-capability (OPS)
      (update m-guards OPS_GUARD
        { "guard": guard }  
      )

      "Rotated OPS to a new guard"
    )
  )

  (defun rotate-gov:string (guard:guard)
    @doc "Requires GOV. Changes the gov guard to the provided one."

    (with-capability (GOV)
      (update m-guards GOV_GUARD
        { "guard": guard }  
      )

      "Rotated GOV to a new guard"
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

  (defun pool-is-locked:bool (start-time:time lock-time:decimal)
    @doc "Returns whether the pool is locked based on start time and lock time"
    
    (and 
      (>= (curr-time) start-time) 
      (< (curr-time) (add-time start-time lock-time))
    )
  )

  (defun is-claimable:bool (stake-start-time:time pool-status:string)
    @doc "True if it is possible to claim"
    (and (> (curr-time) stake-start-time) (= pool-status STATUS_ACTIVE))
  )

  (defun require-WITHDRAW:bool (pool-name:string)
    (require-capability (WITHDRAW))
    true
  )

  (defun pool-guard:guard (pool-name:string)
    @doc "Creates a guard that is used for the bank of the pool"
    (create-user-guard (require-WITHDRAW pool-name))
  )

  (defun pool-account-name:string (pool-name:string)
    (create-principal (pool-guard pool-name))
  )
  
  (defun withdraw-from-bank:string (pool-name:string receiver:string amount:decimal)
    @doc "Ops function that enables bonded NFT managers to withdraw from a pool's bank. \
    \ Expects that the receiver exists."
    (with-capability (OPS)
      (with-read nft-pools pool-name
        { "payout-bank" := payout-bank
        , "payout-coin" := payout-coin:module{fungible-v2} }
        
        (install-capability (payout-coin::TRANSFER payout-bank receiver amount))
        (payout-coin::transfer payout-bank receiver amount)

        ;  (concat ["Withdrew " (int-to-str 10 (floor amount)) " coins (Rounded down) from " payout-bank])
        (format "Withdrew {} coins from {}" [amount payout-bank])
      )
    )
  )

  (defun key:string ( pool-name:string account:string )
    @doc "DB key for staked nft record"
    (concat [pool-name ":" account])
  )

  (defun curr-time:time ()
    @doc "Returns current chain's block-time in time type"

    (at 'block-time (chain-data))
  )

  (defun init:string (gov:guard ops:guard)
    @doc "Initializes the guards and creates the tables for the module"

    ;; This is only vulnerable if GOV_GUARD doesn't exist
    ;; Which means it's only vulnerable if you don't call 
    ;; init when you deploy the contract.
    ;; So let us be sure that init is called. =)
    (insert m-guards GOV_GUARD
      { "guard": gov }  
    )
    (insert m-guards OPS_GUARD
      { "guard": ops }  
    )
  )
)

(if (read-msg "init")
  [
    (create-table free.marmalade-nft-staking.m-guards)
    (create-table free.marmalade-nft-staking.nft-pools)
    (create-table free.marmalade-nft-staking.staked-nfts)
    (free.marmalade-nft-staking.init (read-keyset "gov") (read-keyset "ops"))
  ]
  "No init")