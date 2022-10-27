(namespace "free")

(module marmalade-nft-bonding GOV
  @doc "A contract that is used to give marmalade NFTs a bond value. \
  \ The contract defines the bonded value of the NFT, and the time to maturity. \
  \ Tokens are claimable once the bond matures."

  (defcap GOV ()
    (enforce-guard (at "guard" (read m-guards GOV_GUARD ["guard"])))
  )

  ;; -------------------------------
  ;; Constants

  (defconst STATUS_ACTIVE:string "ACTIVE"
    @doc "Active means the bond will be claimable at the time of maturity.")
  (defconst STATUS_CANCELED:string "CANCELED"
    @doc "Canceled means the bond will not be claimable at the time of maturity.")
  
  (defconst GOV_GUARD:string "gov")
  (defconst OPS_GUARD:string "ops")

  ;; -------------------------------
  ;; Schemas

  (defschema m-guard ;; ID is a const: OPS_GUARD, GOV_GUARD etc.
    @doc "Stores guards for the module"
    guard:guard  
  )

  (defschema bonded-nft ;; ID is the pool-name
    @doc "Stores the information on the bonded NFT"
    pool-name:string
    token-id:string
    payout-coin:module{fungible-v2}
    payout-bank:string
    escrow:string
    token-value:decimal
    mature-time:time ;; Defines when the tokens will be claimable
    status:string ;; Used to cancel a bond
  )
  
  (deftable m-guards:{m-guard})
  (deftable bonded-nfts:{bonded-nft})

  ;; -------------------------------
  ;; Capabilities

  (defcap OPS ()
    (enforce-guard (at "guard" (read m-guards OPS_GUARD ["guard"])))
    (compose-capability (WITHDRAW))
  )

  (defcap CLAIM (pool-name:string account:string)
    @doc "Ensures that only the owner of the NFT can claim from a matured pool."
    (with-read bonded-nfts pool-name
      { "token-id" := token-id }
      (enforce-guard (at "guard" (marmalade.ledger.details token-id account)))
    )
    (compose-capability (WITHDRAW))
  )

  (defcap WITHDRAW ()
    @doc "Used to give permission to withdraw money from the bank"
    true
  )

  ;; -------------------------------
  ;; Bonded NFT Managing

  (defun create-bonded-nft:string 
    (
      pool-name:string
      token-id:string 
      payout-coin:module{fungible-v2}
      token-value:decimal
      mature-time:time
    )
    @doc "Creates a bonded nft with necessary parameters. \
    \ Creates a bank account that is managed by the module guard."

    (enforce (> token-value 0.0) "Value must be greater than 0")

    (with-capability (OPS)
      ; Create the bank account with the pool module guard
      (let
        (
          (p-guard (pool-guard pool-name))
          (account-name (pool-account-name pool-name))
        )

        (payout-coin::create-account account-name p-guard)
        (marmalade.ledger.create-account token-id account-name p-guard)

        ; Create the bonded nft record
        (insert bonded-nfts pool-name
          {
              "pool-name": pool-name
            , "token-id": token-id
            , "payout-coin": payout-coin
            , "payout-bank": account-name
            , "escrow": account-name
            , "token-value": token-value
            , "mature-time": mature-time 
            , "status": STATUS_ACTIVE
          }
        )
      )
    )
  )

  ;; -------------------------------
  ;; Claiming

  (defun claim:string (pool-name:string account:string)
    @doc "Claims the tokens that are available to the account in the given pool. \
    \ Enforces the marmalade ledger account guard."
    
    (with-capability (CLAIM pool-name account)
      (with-read bonded-nfts pool-name
        { "token-id" := token-id
        , "token-value" := token-value
        , "payout-bank" := bank
        , "escrow" := escrow
        , "payout-coin" := payout-coin:module{fungible-v2}
        , "mature-time" := mature-time
        , "status" := status }
        (enforce (can-claim mature-time status) 
          "Can't claim from the pool, make sure it is active, and that it has matured.")
        
        ; Get the info from the marmalade account that we need
        (bind (marmalade.ledger.details token-id account)
          { "balance" := balance
          , "guard" := guard }
          ; Calculate the claimable amount, and transfer it to the individual
          (let*
            (
              (to-claim (* token-value balance))
            )
            
            ; Transfer them the funds
            (install-capability (payout-coin::TRANSFER bank account to-claim))
            (payout-coin::transfer-create bank account guard to-claim)

            ; Take their bonded NFT, give them the keepsake
            (marmalade.ledger.transfer token-id account escrow balance)
            ; TODO: Give them a keepsake NFT, represents a redeemed bond 

            (format "Claimed {} tokens." [to-claim])
          )
        )
      )
    )
  )

  ;; -------------------------------
  ;; Getters and Setters

  (defun get-pools:[object{bonded-nft}] ()
    (select bonded-nfts (where "pool-name" (!= "")))
  )

  (defun get-pool-details:object{bonded-nft} (pool-name:string)
    (read bonded-nfts pool-name)
  )

  (defun get-pool-status:string (pool-name:string)
    (at "status" (read bonded-nfts pool-name ["status"]))
  )

  (defun get-pool-nft-value:decimal (pool-name:string)
    (at "token-value" (read bonded-nfts pool-name ["token-value"]))
  )

  (defun get-pool-mature-time:time (pool-name:string)
    (at "mature-time" (read bonded-nfts pool-name ["mature-time"]))
  )

  (defun get-pool-bank:string (pool-name:string)
    (at "payout-bank" (read bonded-nfts pool-name ["payout-bank"]))
  )

  (defun get-pool-escrow:string (pool-name:string)
    (at "escrow" (read bonded-nfts pool-name ["escrow"]))
  )

  (defun get-pool-token-id:string (pool-name:string)
    (at "token-id" (read bonded-nfts pool-name ["token-id"]))
  )

  (defun get-pool-time-to-maturity:decimal (pool-name:string)
    @doc "Gets the time to maturity in seconds."
    (diff-time (get-pool-mature-time pool-name) (curr-time))
  )

  (defun pool-is-active:bool (pool-name:string)
    @doc "Checks to see if the pool is active"
    (with-read bonded-nfts pool-name 
      { "status" := status }
      
      (= status STATUS_ACTIVE)
    )
  )

  (defun pool-has-matured:bool (pool-name:string)
    @doc "Checks to see if the pool has matured"
    (with-read bonded-nfts pool-name 
      { "mature-time" := mature-time } 
      
      (< (diff-time mature-time (curr-time)) 0.0)
    )
  )

  (defun can-claim-from-pool:bool (pool-name:string)
    @doc "Can claim if: pool has matured, and is active"
    (with-read bonded-nfts pool-name 
      { "mature-time" := mature-time
      , "status" := status
      }
      (can-claim mature-time status)
    )
  )

  (defun can-claim:bool (mature-time:time status:string)
    (and 
      (= status STATUS_ACTIVE) 
      (< (diff-time mature-time (curr-time)) 0.0)
    )
  )

  (defun get-claimable-tokens:decimal (pool-name:string account:string)
    @doc "Gets the claimable tokens for this pool."
    (if (can-claim-from-pool pool-name)
      (get-claimable-at-maturity pool-name account)
      0.0 ;; Return 0 if we can't claim
    )
  )

  (defun get-claimable-at-maturity:decimal (pool-name:string account:string)
    @doc "Returns the total tokens claimable for the given account after maturity."

    (with-read bonded-nfts pool-name
      { "token-id" := token-id
      , "token-value" := value }  
      
      (let
        (
          (balance (at "balance" (marmalade.ledger.details token-id account)))
        )
        
        (* balance value)
      )
    )
  )

  (defun set-pool-status:string (pool-name:string status:string)
    @doc "Requires OPS. Sets the status of the pool to the provided one."

    (with-capability (OPS)
      (enforce (or (= status STATUS_ACTIVE) (= status STATUS_CANCELED)) "Status must be ACTIVE or CANCELED")

      (update bonded-nfts pool-name
        { "status": status }
      )

      (concat ["Pool status updated to: " status])
    )
  )

  (defun set-pool-token-value:string (pool-name:string new-value:decimal)
    @doc "Requires OPS. Sets the token value of the pool to the provided one. Value must be greater than 0."

    (with-capability (OPS)
      (enforce (> new-value 0.0) "Value must be greater than 0")

      (update bonded-nfts pool-name
        { "token-value": new-value }
      )

      (format "Pool nft value updated to: {}" [new-value])
    )
  )

  (defun set-pool-mature-time:string (pool-name:string new-time:time)
    @doc "Requires OPS. Sets the mature time of the pool to the provided one."

    (with-capability (OPS)
      (update bonded-nfts pool-name
        { "mature-time": new-time }
      )

      (format "Pool mature time updated to: {}" [new-time])
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
      (with-read bonded-nfts pool-name
        { "payout-bank" := payout-bank
        , "payout-coin" := payout-coin:module{fungible-v2} }
        
        (install-capability (payout-coin::TRANSFER payout-bank receiver amount))
        (payout-coin::transfer payout-bank receiver amount)

        ;  (concat ["Withdrew " (int-to-str 10 (floor amount)) " coins (Rounded down) from " payout-bank])
        (format "Withdrew {} coins from {}" [amount payout-bank])
      )
    )
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
    (create-table free.marmalade-nft-bonding.m-guards)
    (create-table free.marmalade-nft-bonding.bonded-nfts)
    (free.marmalade-nft-bonding.init (read-keyset "gov") (read-keyset "ops"))
  ]
  "No init")