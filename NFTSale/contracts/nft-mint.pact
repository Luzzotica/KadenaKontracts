(namespace "free")

(module nft-mint GOV
  @doc "The smart contract that is used to mint nft nfts in Tiers."

  ;; -------------------------------
  ;; Governance and Permissions

  (defcap GOV ()
    (enforce-guard (free.nft-perms.get-gov-guard))
    (compose-capability (OPS_INTERNAL))
  )

  (defcap OPS ()
    (enforce-guard (free.nft-perms.get-ops-guard))
    (compose-capability (OPS_INTERNAL))
  )

  (defcap OPS_INTERNAL ()
    (compose-capability (MINT))
  )

  ;; -------------------------------
  ;; Collection and Tiers

  (defconst TIER_TYPE_WL:string "WL")
  (defconst TIER_TYPE_PUBLIC:string "PUBLIC")

  (defschema tier
    @doc "Stores the start time, end time, tier type (WL, PUBLIC), \
    \ tier-id, cost for this tier to mint, \
    \ and the limit for each minter."
    tier-id:string
    tier-type:string
    start-time:time
    end-time:time
    cost:decimal
    limit:decimal
  )

  (defschema collection
    @doc "Stores the name of the collection, the tiers, \
    \ the total supply of the collection. \
    \ The id is the name of the collection."
    name:string
    total-supply:integer
    bank-account:string
    bank-guard:guard
    provenance:string
    root-uri:string
    current-index:integer
    fungible:module{fungible-v2}
    tiers:[object:{tier}]
  )
  (deftable collections:{collection})

  (defun create-collection:string 
    (
      collection-data:object
      fungible:module{fungible-v2}
      bank-guard:guard
    )
    @doc "Requires OPS. Creates a collection with the provided data."
    (with-capability (OPS)
      ; Validate the collection tiers
      (enforce (> (at "total-supply" collection-data) 0.0) "Total supply must be greater than 0")
      (validate-tiers (at "tiers" collection-data))

      ; Create the bank account
      (insert collections (at "name" collection-data)
        (+ 
          { "fungible": fungible
          , "current-index": 1
          , "bank-account": (create-principal bank-guard)
          , "bank-guard": bank-guard
          , "total-supply": (floor (at "total-supply" collection-data))
          }
          collection-data
        )
      )
    )
  )

  (defun update-collection-tiers 
    (
      collection:string 
      tiers:[object:{tier}]
    )
    @doc "Updates the tiers of the given collection"
    (with-capability (OPS)
      (validate-tiers tiers)
      (update collections collection
        { "tiers": tiers }
      )
    )
  )

  (defun update-collection-uri 
    (
      collection:string
      uri:string
    )
    (with-capability (OPS)
      (update collections collection
        { "root-uri": uri }
      )
    )
  )

  (defun validate-tiers:bool (tiers:[object:{tier}])
    @doc "Validates the tier start and end time, ensuring they don't overlap \
    \ and that start is before end for each."
    (let*
      (
        (no-overlap
          (lambda (tier:object{tier} other:object{tier})
            ;; If the other is the same as the tier, don't check it
            (if (!= (at "tier-id" tier) (at "tier-id" other))
              (enforce 
                (or
                  ;; Start and end of other is before start of tier
                  (and? 
                    (<= (at "start-time" other))
                    (<= (at "end-time" other)) 
                    (at "start-time" tier)
                  )
                  ;; Start and end of other is after end of tier
                  (and?
                    (>= (at "end-time" other))
                    (>= (at "start-time" other)) 
                    (at "end-time" tier)
                  )
                )
                "Tiers overlap"
              )
              []
            )
          )
        )
        (validate-tier 
          (lambda (tier:object{tier})
            ;; Enforce start time is before end time, 
            ;; and that the tier type is valid
            (enforce
              (<= (at "start-time" tier) (at "end-time" tier)) 
              "Start must be before end"
            )
            (enforce
              (or 
                (= (at "tier-type" tier) TIER_TYPE_WL)
                (= (at "tier-type" tier) TIER_TYPE_PUBLIC)
              )
              "Invalid tier type"
            )
            (enforce
              (>= (at "cost" tier) 0.0)
              "Cost must be greater than 0"
            )
            ;; Loop through all the tiers and ensure they don't overlap
            (map (no-overlap tier) tiers)
          )
        )
      )
      (map (validate-tier) tiers)
    )
  )

  (defun get-current-tier-for-collection:object{tier} (collection:string)
    @doc "Gets the current tier for the collection"
    (with-read collections collection
      { "tiers":= tiers}
      (get-current-tier tiers)
    )
  )

  (defun get-current-tier:object{tier} (tiers:[object:{tier}])
    @doc "Gets the current tier from the list based on block time"
    (let*
      (
        (now (at "block-time" (chain-data)))
        (filter-tier
          (lambda (tier:object{tier})
            (if (= (at "start-time" tier) (at "end-time" tier)) 
              (>= now (at "start-time" tier))  
              (and? 
                (<= (at "start-time" tier))
                (> (at "end-time" tier))
                now
              )
            )
          )
        )
        (filtered-tiers (filter (filter-tier) tiers))
      )
      (enforce (> (length filtered-tiers) 0) (format "No tier found: {}" [now]))
      (at 0 filtered-tiers)
    )
  )

  (defun get-collection-data:object{collection} (collection:string)
    (read collections collection)
  )

  (defun get-collection-uri:string (collection:string)
    (at "root-uri" (read collections collection ["root-uri"]))
  )

  (defun get-total-supply-for-collection:decimal (collection:string)
    (at "total-supply" (read collections collection ["total-supply"]))
  )

  (defun get-current-index-for-collection:integer (collection:string)
    (at "current-index" (read collections collection ["current-index"]))
  )

  (defun get-bank-for-collection:string (collection:string)
    (at "bank-account" (read collections collection ["bank-account"]))
  )

  ;; -------------------------------
  ;; Whitelist Handling

  (defcap WHITELIST_UPDATE () 
    true
  )

  (defschema whitelisted
    @doc "Stores the account of the whitelisted user, the tier-id, \
    \ and amount they have minted. The id is 'collection:tier-id:account'."
    account:string
    tier-id:string 
    mint-count:integer 
  )
  (deftable whitelist-table:{whitelisted})

  (defschema tier-whitelist-data
    @doc "A data structure for the whitelist data for a tier"
    tier-id:string
    accounts:[string]
  )

  (defun add-whitelist-to-collection
    (
      collection:string 
      tier-data:[object{tier-whitelist-data}]
    )
    @doc "Requires OPS. Adds the accounts to the whitelist for the given tier."
    (with-capability (OPS)
      (let
        (
          (handle-tier-data 
            (lambda (tier-data:object{tier-whitelist-data})
              (let
                (
                  (tier-id (at "tier-id" tier-data))
                  (whitelist (at "accounts" tier-data))
                )
                (map (add-to-whitelist collection tier-id) whitelist)
              )   
            )
          )
        )
        (map (handle-tier-data) tier-data)
      )
    )
  )

  (defun add-to-whitelist:string 
    (
      collection:string 
      tier-id:string
      account:string 
    )
    @doc "Requires private OPS. Adds the account to the whitelist for the given tier."
    (require-capability (OPS))

    (insert whitelist-table (get-whitelist-id collection tier-id account)
      { "tier-id": tier-id
      , "account": account
      , "mint-count": 0
      }
    )
  )

  (defun is-whitelisted:bool 
    (
      collection:string 
      tier-id:string 
      account:string
    )
    @doc "Returns true if the account is whitelisted for the given tier."
    (with-default-read whitelist-table (get-whitelist-id collection tier-id account)
      { "mint-count": -1 }
      { "mint-count":= mint-count }
      (!= mint-count -1)
    )
  )

  (defun get-whitelist-mint-count:integer
    (
      collection:string 
      tier-id:string 
      account:string
    )
    (with-default-read whitelist-table (get-whitelist-id collection tier-id account)
      { "mint-count": -1 }
      { "mint-count":= mint-count }
      mint-count
    )
  )

  (defun get-whitelist-id:string 
    (
      collection:string 
      tier-id:string 
      account:string
    )
    (concat [collection "|" tier-id "|" account])
  )

  (defun update-whitelist-mint-count 
    (
      collection:string 
      tier-id:string 
      account:string 
      count:integer
    )
    @doc "Requires Whitelist Update. Updates the mint count for the given account in the whitelist."
    (require-capability (WHITELIST_UPDATE))

    (update whitelist-table (get-whitelist-id collection tier-id account)
      { "mint-count": count }
    )
  )

  ;; -------------------------------
  ;; Minting and Reveal

  (defcap MINT () 
    (compose-capability (WHITELIST_UPDATE))
    true
  )

  (defcap MINT_EVENT 
    (
      collection:string 
      tier-id:string 
      account:string 
      amount:integer
    )
    @event true
  )

  (defschema minted-token
    @doc "Stores the data for a minted token. \
    \ The id is the collection, tier-id, account, and token-id."
    collection:string
    account:string
    guard:guard
    token-id:integer
    hash:string
    revealed:bool
  )
  (deftable minted-tokens:{minted-token})

  (defun admin-mint:string
    (
      collection:string 
      account:string 
      guard:guard
      amount:integer
    )
    @doc "Requires OPS. Mints the given amount of tokens \
    \ for the account for free."
    (with-capability (OPS)
      (let*
        (
          (collection-data (read collections collection))
          (current-index (at "current-index" collection-data))
          (tier (get-current-tier (at "tiers" collection-data)))
          (tier-id (at "tier-id" tier))
        )
        
        (mint-internal 
          collection 
          account 
          guard
          amount 
          tier-id 
          current-index
        )
      )
    )
  )

  (defun mint:bool 
    (
      collection:string 
      account:string 
      amount:integer
    )
    @doc "Mints the given amount of tokens for the account. \
    \ Gets the current tier and tries to mint from it. \
    \ If the tier is a whitelist, checks that the account is whitelisted \
    \ and that the mint count is wthin the limit. \
    \ If the tier is public, it allows anyone to mint."
    (enforce (> amount 0) "Amount must be greater than 0")

    (with-capability (MINT)
      (with-read collections collection
        { "current-index":= current-index
        , "total-supply":= total-supply
        , "fungible":= fungible:module{fungible-v2}
        , "bank-account":= bank-account:string
        , "bank-guard":= bank-guard
        , "tiers":= tiers
        }
        (enforce 
          (<= (+ (- current-index 1) amount) total-supply) 
          "Can't mint more than total supply"
        )

        (bind (get-current-tier tiers)
          { "cost":= cost
          , "tier-type":= tier-type
          , "tier-id":= tier-id
          , "limit":= mint-limit
          }
          (let 
            (
              (mint-count (get-whitelist-mint-count collection tier-id account))
            )  
            ;; If the tier is public, anyone can mint
            ;; If the mint count is -1, the account is not whitelisted
            (enforce 
              (or 
                (= tier-type TIER_TYPE_PUBLIC)
                (!= mint-count -1)
              )
              "Account is not whitelisted"
            )
            ;; If the mint limit is -1, there is no limit
            ;; If the mint count is less than the limit, the account can mint
            (enforce 
              (or 
                (= mint-limit -1.0)
                (<= (+ mint-count amount) (floor mint-limit))
              )
              "Mint limit reached"
            )

            ;; Transfer funds if the cost is greater than 0
            (if (> cost 0.0)
              (fungible::transfer-create 
                account 
                bank-account 
                bank-guard 
                (* amount cost)
              )
              []
            )

            ;; Handle the mint
            (if (= tier-type TIER_TYPE_WL)
              (update-whitelist-mint-count collection tier-id account (+ mint-count amount))
              []
            )
            (mint-internal 
              collection 
              account 
              (at "guard" (fungible::details account)) 
              amount
              tier-id 
              current-index
            )
          )
        )
      )
    )
  )

  (defun mint-internal:bool
    (
      collection:string 
      account:string 
      guard:guard
      amount:integer
      tier-id:string
      current-index:integer
    )
    (require-capability (MINT))  

    (update collections collection 
      { "current-index": (+ current-index amount) }
    )
    (map 
      (mint-token collection account guard) 
      (map (+ current-index) (enumerate 0 (- amount 1)))
    )
    (emit-event (MINT_EVENT collection tier-id account amount))
  )

  (defun mint-token:string 
    (
      collection:string 
      account:string 
      guard:guard
      token-id:integer
    )
    @doc "Mints a single token for the account."
    (require-capability (MINT))
    (insert minted-tokens (get-mint-token-id collection token-id)
      { "collection": collection
      , "account": account
      , "guard": guard
      , "token-id": token-id
      , "hash": ""
      , "revealed": false
      }
    )
  )

  (defschema in-token-data
    @doc "The information necessary to mint the token on marmalade"
    scheme:string 
    data:string
    datum:object
  )

  (defun reveal-token:string 
    (
      m-token:object{minted-token}
      t-data:object{in-token-data}
      precision:integer
      policy:module{kip.token-policy-v1}
    )
    @doc "Requires OPS. Reveals the token for the given account."
    (with-capability (OPS)
      (bind m-token
        { "collection":= collection
        , "token-id":= token-id
        , "account":= account
        , "guard":= guard
        }

        (create-marmalade-token 
          account 
          guard 
          (get-mint-token-id collection token-id)
          (+ 
            t-data 
            { "precision": precision
            , "policy": policy
            }
          )
        )
      )
    )
  )

  (defschema token-data
    @doc "The information necessary to mint the token on marmalade"
    precision:integer
    scheme:string 
    data:string
    datum:object
    policy:module{kip.token-policy-v1} 
  )

  (defun create-marmalade-token:string 
    (
      account:string
      guard:guard 
      mint-token-id:string
      t-data:object{token-data}
    )
    @doc "Requires Private OPS. Creates the token on marmalade using the supplied data"
    (require-capability (OPS_INTERNAL))

    (bind t-data
      { "precision":= precision
      , "scheme":= scheme
      , "data":= data
      , "datum":= datum
      , "policy":= policy
      }
      (let*
        (
          (uri (kip.token-manifest.uri scheme data))
          (datum-complete (kip.token-manifest.create-datum uri datum))
          (manifest (kip.token-manifest.create-manifest uri [datum-complete]))
          (token-id (concat ["t:" (at "hash" manifest)]))
        )
        (update minted-tokens mint-token-id
          { "revealed": true
          , "hash": (at "hash" manifest)
          }
        )

        (marmalade.ledger.create-token 
          token-id
          precision
          manifest
          policy
        )
        ;  (install-capability (marmalade.ledger.MINT token-id account 1.0))
        (marmalade.ledger.mint
          token-id
          account
          guard
          1.0
        )
        token-id
      )
    )
  )

  (defun get-tokens-for-collection:[object:{minted-token}] 
    (
      collection:string
    )
    @doc "Returns a list of tokens for the collection."
    (select minted-tokens (where "collection" (= collection)))
  )

  (defun get-unrevealed-tokens-for-collection:[object:{minted-token}] 
    (
      collection:string
    )
    @doc "Returns a list of unrevealed tokens."
    (select minted-tokens 
      (and? 
        (where "revealed" (= false))
        (where "collection" (= collection))
      )
    )
  )

  (defun get-owned:[object:{minted-token}] 
    (
      account:string
    )
    @doc "Returns a list of tokens owned by the account."
    (select minted-tokens (where "account" (= account)))
  )

  (defun get-owned-for-collection:[object:{minted-token}] 
    (
      account:string
      collection:string
    )
    @doc "Returns a list of tokens owned by the account."
    (select minted-tokens 
      (and? 
        (where "account" (= account))
        (where "collection" (= collection))
      )
    )
  )

  (defun get-mint-token-id:string 
    (
      collection:string 
      token-id:integer
    )
    (concat [collection "|" (int-to-str 10 token-id)])
  )
)

(if (read-msg "upgrade")
  "Contract upgraded"
  [
    (create-table collections)
    (create-table whitelist-table)
    (create-table minted-tokens)
    (create-collection 
      (read-msg "collection") 
      coin 
      (read-keyset "bank-guard")
    )
    (add-whitelist-to-collection 
      (read-msg "collection-name")
      (read-msg "tier-data")
    )
  ]
)