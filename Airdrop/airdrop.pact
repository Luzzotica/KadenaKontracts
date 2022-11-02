(namespace "free")

(module airdrop GOV
  @doc "A contract that is used airdrop NFTs and coins to people."

  ;; -------------------------------
  ;; Governance, permissions, and init

  (defconst GOV_GUARD:string "gov")

  (defcap GOV ()
    (enforce-guard (at "guard" (read gov-guards GOV_GUARD ["guard"])))
  )

  (defschema gov-guard ;; ID is a const: OPS_GUARD, etc.
    @doc "Stores guards for the module"
    guard:guard  
  )

  (deftable gov-guards:{gov-guard})

  (defun init:string (gov:guard)
    @doc "Initializes the guards for the module"

    ;; This is only vulnerable if GOV_GUARD doesn't exist
    ;; Which means it's only vulnerable if you don't call 
    ;; init when you deploy the contract.
    ;; So let us be sure that init is called. =)
    (insert gov-guards GOV_GUARD
      { "guard": gov }  
    )
  )

  ;; -------------------------------
  ;; Airdropping Caps

  (defcap MANAGED (account:string)
    @doc "Checks to make sure the guard for the given account name is satisfied"
    (enforce-guard (at "guard" (read managed-accounts account ["guard"])))
  )

  (defun require-MANAGED (account:string)
    @doc "The function used when building the user guard for managed accounts"
    (require-capability (MANAGED account))
  )

  (defun create-MANAGED-guard (account:string)
    @doc "Creates the user guard"
    (create-user-guard (require-MANAGED account))
  )

  (defschema managed-account ; ID is the account
    @doc "Stores each account and its guard"
    account:string
    guard:guard
    k-account:string
  )
  (deftable managed-accounts:{managed-account})

  ;; -------------------------------
  ;; Managed Account

  (defun create-managed-account-from-k:string 
    (
      account:string 
      k-account:string
    )
    @doc "Creates a managed account. \
    \ Managed accounts allows smart contracts to install capabilities for them, \
    \ but they still require the root user's keyset."

    ; Create the managed account locally
    (insert managed-accounts account
      { "account": account
      , "guard": (at "guard" (coin.details k-account))
      , "k-account": k-account
      }
    )
  )

  (defun create-managed-account:string 
    (
      account:string 
      guard:guard
      k-account:string
    )
    @doc "Creates an unguarded account with the provided coin contract. \
    \ Unguarded account allows smart contracts to install capabilities for them, \
    \ but they still require the root user's keyset"

    ; Create the managed account locally
    (insert managed-accounts account
      { "account": account
      , "guard": guard
      , "k-account": k-account
      }
    )
  )

  (defun add-coin-to-managed-account:string 
    (
      account:string 
      token:module{fungible-v2}
    )
    @doc "Creates an unguarded account with the provided coin contract. \
    \ Unguarded account allows smart contracts to install capabilities for them, \
    \ but they still require the root user's keyset"
    
    (with-capability (MANAGED account)
      ; Create it in the provided coin
      (token::create-account 
        account
        (create-MANAGED-guard account)
      )
    )
  )

  (defun add-nft-to-managed-account:string 
    (
      account:string 
      ledger:module{kip.poly-fungible-v2}
      token-id:string
    )
    @doc "Creates a managed account with the provided ledger contract. \
    \ Managed account allows smart contracts to install capabilities for them, \
    \ but they still require the root user's keyset"

    (with-capability (MANAGED account)
      ; Create it in the provided coin
      (ledger::create-account 
        token-id
        account
        (create-MANAGED-guard account)
      )
    )
  )

  ;; -------------------------------
  ;; Coin Airdropping

  (defun airdrop-coin:[string] 
    (
      sender:string 
      managed-account:string 
      token:module{fungible-v2} 
      amount:decimal
      recipients:[string] 
    )
    @doc "Used to airdrop the given amount of coin to each individual"

    (with-capability (MANAGED managed-account)
      ; Transfer funds to the contract: amount * number of recipients
      (let 
        (
          (to-transfer (* amount (length recipients)))
        )
        (token::transfer sender managed-account to-transfer)
      )
      
      ; Go through each recipient and transfer them the funds
      (map (coin-transfer-helper managed-account token amount) recipients)
    )
  )

  (defun split-coin:[string] 
    (
      sender:string 
      managed-account:string 
      token:module{fungible-v2} 
      amount:decimal
      recipients:[string] 
    )
    @doc "Used to split the given amount between each recipient evenly"

    (with-capability (MANAGED managed-account)
      ; Transfer funds to the contract: amount is correct
      (token::transfer sender managed-account amount)

      (let 
        (
          (amount-per (/ amount (length recipients)))
        )
        ; Go through each recipient and transfer them the funds
        (map (coin-transfer-helper managed-account token amount-per) recipients)
      )
    )
  )

  (defun coin-transfer-helper 
    (
      managed-account:string 
      token:module{fungible-v2}
      amount:decimal 
      recipient:string
    )
    @doc "Private function used to transfer funds from \
    \ an unguarded account to given recipient"
    (require-capability (MANAGED managed-account))

    (install-capability (token::TRANSFER managed-account recipient amount))
    (token::transfer managed-account recipient amount)
    (concat ["Airdropped to " recipient " successfully"])
  )

  ;; -------------------------------
  ;; Marmalade NFT Airdropping

  (defun airdrop-nft:[string] 
    (
      sender:string 
      managed-account:string 
      ledger:module{kip.poly-fungible-v2} 
      token-id:string
      amount:decimal
      recipients:[string] 
    )
    @doc "Used to airdrop the given amount of marmalade nfts to each individual"

    (with-capability (MANAGED managed-account)
      ; Transfer funds to the contract: amount * number of recipients
      (let 
        (
          (to-transfer (* amount (length recipients)))
        )
        (ledger::transfer token-id sender managed-account to-transfer)
      )
      
      ; Go through each recipient and transfer them the funds
      (map (nft-transfer-helper managed-account ledger token-id amount) recipients)
    )
  )

  (defun nft-transfer-helper 
    (
      managed-account:string 
      ledger:module{kip.poly-fungible-v2}
      token-id:string
      amount:decimal 
      recipient:string
    )
    @doc "Private function used to transfer funds from \
    \ an unguarded account to given recipient"
    (require-capability (MANAGED managed-account))

    (install-capability (ledger::TRANSFER token-id managed-account recipient amount))
    (ledger::transfer token-id managed-account recipient amount)
    (concat ["Airdropped to " recipient " successfully"])
  )

  ;; -------------------------------
  ;; Getters

  (defun get-managed-accounts-for-k-account:[object] (k-account:string)
    @doc "Gets all of the managed accounts for the given k-account"
    (select managed-accounts ["account"] (where "k-account" (= k-account)))
  )

)

(if (read-msg "init")
  [
    (create-table free.airdrop.gov-guards)
    (create-table free.airdrop.managed-accounts)
    (free.airdrop.init (read-keyset "gov"))
  ]
  "No init, contract upgraded")
