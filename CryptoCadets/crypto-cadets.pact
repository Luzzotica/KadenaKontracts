;  (free.crypto-cadets.init "aeecd476ad8a4842ec84f3fbdad39b73fe7329fb4feaa3ea4367314a29a7e42b" "591649bce0c4a59edb6608ec09046457a35ba2983f999b89945b3ba3b596c0c7")
;  (free.crypto-cadets.create-account-and-mint-planet "aeecd476ad8a4842ec84f3fbdad39b73fe7329fb4feaa3ea4367314a29a7e42b" (read-keyset "crypto-cadets-admin") 25.0)

(namespace (read-msg "ns"))

(define-keyset "crypto-cadets-admin" (read-keyset "crypto-cadets-admin"))
;  (define-keyset "crypto-cadets-op" (read-keyset "crypto-cadets-op"))

(module crypto-cadets GOVERNANCE
  @model
    [ 
      (defproperty valid-account (account:string)
        (and
          (>= (length account) 3)
          (<= (length account) 256)))
    ]

  (use kaddex.kdx [details transfer])

  ; --------------------------------------------------------------------------
  ; Constants

  (defconst VALID_CHAINS (map (int-to-str 10) [0])
    "List of currently valid chain ids")

  (defconst COIN_CHARSET CHARSET_LATIN1
    "The default KDX contract character set")

  (defconst MINIMUM_ACCOUNT_LENGTH 3
    "Minimum account length admissible for KDX accounts")

  (defconst MAXIMUM_ACCOUNT_LENGTH 256
    "Maximum account name length admissible for KDX accounts")

  (defconst MIN_STAKE_AMOUNT_KEY:string "min-stake")
  
  (defconst CURRENT_PLANET_COUNT_KEY:string "current-planet-count")
  
  (defconst FOUNDATION_ADDRESS_KEY "foundation-address")

  (defconst STAKING_ADDRESS_KEY "staking-address")

  ;  (defconst FOUNDATION_MINT_PERCENTAGE_KEY "foundation-mint-percentage")
  ;  (defconst STAKING_MINT_PERCENTAGE_KEY "staking-mint-percentage")
  
  (defconst FOUNDATION_MINT_PERCENTAGE 0.15)
  (defconst STAKING_MINT_PERCENTAGE 0.85)

  ; --------------------------------------------------------------------------
  ; Capabilities

  (defcap PRIVATE ()
    @doc "Can only be called from a private context"
    true
  )

  (defcap GOVERNANCE ()
    "Makes sure only admin account can update the smart contract"
    (enforce-guard (keyset-ref-guard "crypto-cadets-admin"))
    (compose-capability (PRIVATE))
  )

  (defcap MINT (receiver:string stake-amount:decimal)
    "Makes sure the account can mint with the given parameters."
    (with-read amounts-table MIN_STAKE_AMOUNT_KEY
      { "amount" := min-amount }
      (enforce (> stake-amount min-amount) (format "stake amount must be greater than {}" [min-amount]))
    )
  )

  (defcap PLANET_OWNER (planet-id:string)
    (enforce-guard (at "guard" (read planets-table planet-id)))
  )

  (defcap ACCOUNT_OWNER (account:string)
    (enforce-guard (at "guard" (read accounts-table account)))
  )

  (defcap KDX_CAPABLE (account:string stake-amount:decimal)
    (let
      (
        (details (kaddex.kdx.details account))
      )
      (enforce-guard (at "guard" details))
      (enforce (>= (at "balance" details) stake-amount) (format "Must have at least {} tokens available. Current is {}" [stake-amount, (at "balance" details)]))
    )
    ;  true
  )

  (defcap MINT_PLANET (account:string stake-amount:decimal)
    (compose-capability (PRIVATE))
    (compose-capability (ACCOUNT_OWNER account))
    (compose-capability (KDX_CAPABLE account stake-amount))
  )

  ; --------------------------------------------------------------------------
  ; Events

  (defcap NEW_PLANET (owner:string planet-id:string)
    @event
    true
  )

  ; --------------------------------------------------------------------------
  ; Schemas and Tables

  (defschema values
    @doc "Stores the different string values that are used within the smart contract."
    
    value:string
  )

  (defschema amounts
    @doc "Stores the different decimal values that are used within the smart contract."
    
    amount:decimal
  )

  (defschema counts
    @doc "Stores the different integer values that are used within the smart contract."
    
    count:integer
  )

  (defschema planet
    @doc "The planet contract schema, each one represents a different planet. The id is the seed (1, 2, 3...)."
    @model [ (invariant (>= staked-amount 0.0)) ]

    staked-amount:decimal
    guard:guard
  )
  
  (defschema accounts
    @doc "Stores a list of planets owned by the given account. Id is the account name. Only use k: accounts."

    owned-planets:[string]
    guard:guard
  )
  
  (deftable values-table:{values})
  (deftable amounts-table:{amounts})
  (deftable counts-table:{counts})
  (deftable planets-table:{planet})
  (deftable accounts-table:{accounts})

  ; --------------------------------------------------------------------------
  ; Utilities

  (defun get-planets:[string] (account:string)
    @doc "Gets all of the planets owned by the given account"
    (with-read accounts-table account
      { "owned-planets" := planets }
      planets
    )
  )

  (defun get-current-planet-count:integer ()
    @doc "Gets the id of the next planet"

    (with-read counts-table CURRENT_PLANET_COUNT_KEY
      { "count" := planet-count }
      planet-count
    )
  )

  (defun add-to-planet-count:string (count:integer)
    @doc "Adds the count to the current planet count"
    (require-capability (PRIVATE))
    
    (let 
      (
        (current (get-current-planet-count))
      )
      (update counts-table CURRENT_PLANET_COUNT_KEY { "count": (+ current count) })
    )
  )

  (defun set-min-stake-amount:string (new-val:decimal)
    @doc "Updates the min stake amount for new planets"
    (enforce (>= new-val 0) "Value must be greater than 0")
    (with-capability (GOVERNANCE)
      (update amounts-table MIN_STAKE_AMOUNT_KEY { "amount": new-val })
    )
  )

  (defun update-foundation-address (account:string)
    @doc "Sets the foundation address that will receive some percentage of the payment"
    (with-capability (GOVERNANCE)
      (update values-table FOUNDATION_ADDRESS_KEY { "value": account })
    )
  )

  (defun update-staking-address (account:string)
    @doc "Sets the foundation address that will receive some percentage of the payment"
    (with-capability (GOVERNANCE)
      (update values-table STAKING_ADDRESS_KEY { "value": account })
    )
  )

  (defun enforce-valid-chain (chain-id:string)
    @doc "Enforce that the target chain id is valid."
    (enforce (!= "" chain-id) "Empty chain ID")
    (enforce (!= (at 'chain-id (chain-data)) chain-id) "Cannot run cross-chain transfers to the same chain")
    (enforce (contains chain-id VALID_CHAINS) (format "Chain ID {} is invalid or unknown" [chain-id]))
  )

  (defun validate-account (account:string)
    @doc "Enforce that an account name conforms to the Crypto Cadets contract \
         \minimum and maximum length requirements, as well as the    \
         \latin-1 character set."

    (enforce
      (is-charset COIN_CHARSET account)
      (format "Account does not conform to the KDX contract charset: {}" [account]))

    (let 
      (
        (account-length (length account))
      )
      (enforce
        (>= account-length MINIMUM_ACCOUNT_LENGTH)
        (format "Account name does not conform to the min length requirement: {}" [account])
      )
      (enforce
        (<= account-length MAXIMUM_ACCOUNT_LENGTH)
        (format "Account name does not conform to the max length requirement: {}" [account])
      )
    )
  )

  (defun details:object (account:string)
    @doc "Gets all account information"
    (with-read accounts-table account
      { "owned-planets" := planets
      , "guard" := g }
      { "account" : account
      , "owned-planets" : planets
      , "guard": g })
  )

  (defun init (foundation-addr:string staking-addr:string)
    (with-capability (GOVERNANCE)
      (insert amounts-table MIN_STAKE_AMOUNT_KEY { 'amount : 0.0 })
      (insert counts-table CURRENT_PLANET_COUNT_KEY { 'count : 0 })
      (insert values-table FOUNDATION_ADDRESS_KEY { 'value : foundation-addr })
      (insert values-table STAKING_ADDRESS_KEY { 'value : staking-addr })
    )
  )

  ; --------------------------------------------------------------------------
  ; Functions

  (defun create-account:string (account:string)
    @doc "Creates the account, pulls the guard from the kaddex smart contract"
    @model [ (property (valid-account account)) ]
    
    (validate-account account)

    (insert accounts-table account
      { "guard": (at "guard" (kaddex.kdx.details account)),
        "owned-planets": [] }
    )

    (format "Created account: {}" [account])
  )

  (defun mint-planet:string (buyer:string stake-amount:decimal)
    @doc "Mints a new planet and returns the seed to the caller"
    
    (with-capability (MINT_PLANET buyer stake-amount)
      (let 
        (
          (foundation-wallet-amount (* stake-amount FOUNDATION_MINT_PERCENTAGE))
          (stake-wallet-amount (* stake-amount STAKING_MINT_PERCENTAGE))
          (new-planet-id (int-to-str 10 (+ (get-current-planet-count) 1)))
        )
        
        ; Transfer the percentages to the proper addresses, staking will be handled separately
        (kaddex.kdx.transfer buyer (at "value" (read values-table FOUNDATION_ADDRESS_KEY)) foundation-wallet-amount)
        (kaddex.kdx.transfer buyer (at "value" (read values-table STAKING_ADDRESS_KEY)) stake-wallet-amount)
        
        (with-read accounts-table buyer
          { "guard" := account-guard, "owned-planets" := owned-planets }
          
          ; Create the new planet, increment the planet count
          (insert planets-table new-planet-id
            { "staked-amount": stake-wallet-amount, "guard": account-guard }
          )
          (add-to-planet-count 1)

          ; Add the planet to the list of planets the owner has
          (update accounts-table buyer 
            { "owned-planets": (+ owned-planets [new-planet-id]) }
          )
        )

        ; Emit the event saying that the planet was created
        (emit-event (NEW_PLANET buyer new-planet-id))

        (format "Planet ID: {}, foundation amount: {}, staked amount: {}" [new-planet-id foundation-wallet-amount stake-wallet-amount])
      )
    )
  )

  (defun create-account-and-mint-planet:string (account:string stake-amount:decimal)
    @doc "Convenience method to create an account and mint a planet"
    
    (create-account account)
    (mint-planet account stake-amount)
  )
)

(if (read-msg "upgrade")
  [(create-table values-table)
  (create-table amounts-table)
  (create-table counts-table)
  (create-table planets-table)
  (create-table accounts-table)
  (init (read-msg "foundation") (read-msg "staking"))]
  "No Upgrade"
)