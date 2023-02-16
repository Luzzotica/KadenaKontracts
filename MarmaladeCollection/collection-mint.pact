(namespace "free")

(module collection-mint GOV
  @doc "The smart contract that is used to mint collections of NFTs \
  \ using tiers. Each tier has a start and end date, a cost, and a limit. \
  \ The tiers can be WL or public. \
  \ WL tiers require a whitelisted account to mint."

  ;; -------------------------------
  ;; Governance and Permissions

  (defcap GOV ()
    (enforce-keyset "free.collection-gov")
    (compose-capability (OPS_INTERNAL))
  )

  (defcap OPS ()
    (enforce-keyset "free.collection-ops")
    (compose-capability (OPS_INTERNAL))
  )

  (defcap OPS_INTERNAL ()
    true
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
    limit:integer
  )

  (defschema whitelisted
    @doc "Stores the account of the whitelisted user, the tier-id, \
    \ and amount they have minted. The id is 'collection:tier-id:account'."
    account:string
    tier-id:string 
    mint-count:integer 
  )
  (deftable whitelist-table:{whitelisted})

  (defschema collection
    @doc "Stores the name of the collection, the tiers, \
    \ the total supply of the collection. \
    \ The id is the name of the collection."
    name:string
    total-supply:integer
    current-index:integer
    payment-coin:module{kip.fungible-v2}
    tiers:[object:{tier}]
  )
  (deftable collections:{collection})

  (defun create-collection:string 
    (
      collection-data:object
      payment-coin:module{kip.fungible-v2}
    )
    @doc "Requires OPS. Creates a collection with the provided data."
    (with-capability (OPS)
      ; Validate the collection tiers
      (validate-tiers (at "tiers" collection-data))

      (insert collections (at "name" collection-data)
        (+ 
          collection-data
          { "payment-coin": payment-coin
          , "current-index": 0 
          }
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

  (defun validate-tiers:bool (tiers:[object:{tier}])
    @doc "Validates the tier start and end time, ensuring they don't overlap \
    \ and that start is before end for each."
    (let*
      (
        (no-overlap
          (lambda (tier:object{tier} other:object{tier})
            (enforce 
              (or 
                (> (at "start-time" tier) (at "end-time" other))
                (> (at "start-time" other) (at "end-time" tier))
              )
              "Tiers overlap"
            )
          )
        )
        (validate-tier 
          (lambda (tier:object{tier})
            ;; Enforce start time is before end time, 
            ;; and that the tier type is valid
            (enforce 
              (< (at "start-time" tier) (at "end-time" tier)) 
              "Start is before end"
            )
            (enforce
              (or 
                (= (at "tier-type" tier) TIER_TYPE_WL)
                (= (at "tier-type" tier) TIER_TYPE_PUBLIC)
              )
            )
            ;; Loop through all the tiers and ensure they don't overlap
            (map (no-overlap tier) tiers)
          )
        )
      )
      (map (validate-tier) tiers)
    )
  )

  (defun get-current-tier-for-collection (collection:string)
    @doc "Gets the current tier for the collection"
    (let*
      (
        (tiers (at "tiers" (read collections collection)))
      )
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
            (and 
              (>= (at "start-time" tier) now)
              (<= (at "end-time" tier) now)
            )
          )
        )
      )
      (at 0 (filter (filter-tier) tiers))
    )
  )

  ;; -------------------------------
  ;; Whitelist Handling

  (defcap WHITELIST_UPDATE () 
    true
  )

  (defschema tier-whitelist-data
    @doc "A data structure for the whitelist data for a tier"
    tier-id:string
    whitelist:[string]
  )

  (defun add-whitelist-to-tier:[string] 
    (
      collection:string 
      tier-data:object{tier-whitelist-data}
    )
    @doc "Requires OPS. Adds the accounts to the whitelist for the given tier."
    (with-capability (OPS)
      (let
        (
          (tier-id (at "tier-id" tier-data))
          (whitelist (at "whitelist" tier-data))
        )
        (map (add-to-whitelist collection tier-id) whitelist)
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

    (insert whitelist-table (concat [collection ":" tier-id ":" account])
      { 
        "tier-id": tier-id
        "account": account
        "mint-count": 0.0
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
    (let
      (
        (whitelist-id (get-whitelist-id collection tier-id account))
      )
      (with-default-read whitelist-table whitelist-id
        { "mint-count": -1 }
        { "mint-count":= mint-count }
        (!= mint-count -1)
      )
    )
  )

  (defun get-whitelist-mint-count:integer
    (
      collection:string 
      tier-id:string 
      account:string
    )
    (let
      (
        (whitelist-id (get-whitelist-id collection tier-id account))
      )
      (with-default-read whitelist-table whitelist-id
        { "mint-count": -1 }
        { "mint-count":= mint-count }
        mint-count
      )
    )
  )

  (defun get-whitelist-id:string 
    (
      collection:string 
      tier-id:string 
      account:string
    )
    (concat [collection ":" tier-id ":" account])
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

    (let
      (
        (whitelist-id (get-whitelist-id collection tier-id account))
      )
      (update whitelist-table whitelist-id
        { "mint-count": count }
      )
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
    tier-id:string
    account:string
    token-id:integer
    revealed:bool
  )

  (deftable minted-tokens:{minted-token})

  (defun mint:string 
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
    (with-capability (MINT)
      (let*
        (
          (collection-data (read collections collection))
          (current-index (at "current-index" collection-data))
          (tier (get-current-tier (at "tiers" collection)))
          (tier-type (at "tier-type" tier))
          (tier-id (at "tier-id" tier))
          (mint-limit (at "mint-limit" tier))
          (mint-count (get-whitelist-mint-count collection tier-id account))
        )
        (enforce 
          (or 
            (= tier-type TIER_TYPE_PUBLIC)
            (is-whitelisted collection tier-id account)
          )
          "Account is not whitelisted"
        )
        (enforce 
          (or 
            (= mint-limit -1)
            (< (+ mint-count amount) mint-limit)
          )
          "Mint limit reached"
        )

        (update-whitelist-mint-count collection tier-id account (+ mint-count amount))
        (map (mint-token collection tier-id account) (map (+ current-index)) (enumerate 0 amount))
        (emit-event (MINT_EVENT collection tier-id account amount))
      )
    )
  )

  (defun mint-token:string (collection:string tier-id:string account:string token-id:integer)
    @doc "Mints a single token for the account."
    (require-capability (MINT))
    (insert minted-tokens (get-mind-token-id collection tier-id account token-id)
      { "collection": collection
      , "tier-id": tier-id
      , "account": account
      , "token-id": token-id
      , "revealed": false
      }
    )
  )

  (defun reveal-token:string 
    (
      m-token:object{minted-token}
      t-data:object{token-data}
    )
    @doc "Requires OPS. Reveals the token for the given account."
    (with-capability (OPS)
      (let
        (
          (collection (at "collection" m-token))
          (tier-id (at "tier-id" m-token))
          (account (at "account" m-token))
          (token-id (at "token-id" m-token))
        )

        (update minted-tokens (get-mint-token-id collection tier-id account token-id)
          { "revealed": true }
        )

        (create-marmalade-token t-data)
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

  (defun create-marmalade-token:string (t-data:object{token-data})
    @doc "Requires Private OPS. Creates the token on marmalade using the supplied data"
    (require-capability (OPS_INTERNAL))

    (let
      (
        (precision (at "precision" t-data))
        (scheme (at "scheme" t-data))
        (data (at "data" t-data))
        (datum (at "datum" t-data))
        (policy (at "policy" t-data))
      )
      (let*
        (
          (uri (kip.token-manifest.uri scheme data))
          (datum-complete (kip.token-manifest.create-datum uri datum))
          (manifest (kip.token-manifest.create-manifest uri [datum-complete]))
        )
        (marmalade.ledger.create-token 
          (concat "t:" (at "hash" manifest)) 
          precision 
          manifest
          policy
        )
      )
    )
  )

  (defun get-unrevealed-tokens[object:{minted-token}] ()
    @doc "Returns a list of unrevealed tokens."
    (select minted-tokens (where "revealed" false))
  )

  (defun get-mint-token-id:string 
    (
      collection:string 
      tier-id:string 
      account:string 
      token-id:integer
    )
    (concat [collection ":" tier-id ":" account ":" (int-to-str 10 token-id)])
  )
)

(if (read-msg "upgrade")
  "Contract upgraded"
  [
    (create-table collections)
    (create-table whitelist-table)
    (create-table minted-tokens)
  ]
)