(namespace "free")

(module collection-policy GOV
  @doc "Generic policy for a collection of NFTs."

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
    (compose-capability (INTERMEDIARY))
    true
  )

  ;; -------------------------------
  ;; Bool Values

  (defconst CAN_BURN:string "CAN_BURN")
  (defconst CAN_TRANSFER:string "CAN_TRANSFER")
  (defconst CAN_XCHAIN:string "CAN_XCHAIN")

  (defschema bool-value
    @doc "Stores the boolean values for things like transfer/offer enforcing. \
    \ Enables turning it on and off at will."
    value:bool
  )
  (deftable bool-values:{bool-value})

  (defun update-bool-value (val-id:string value:bool)
    @doc "Updates the account for the bank"

    (with-capability (OPS)
      (write bool-values val-id
        { "value": value }
      )
    )
  )

  (defun get-bool-value:string (val-id:string)
    @doc "Gets the value with the provided id"

    (at "value" (read bool-values val-id ["value"]))
  )

  ;; -------------------------------
  ;; Royalties

  (implements free.has-royalty-v1)
  (use free.has-royalty-v1 [token-royalty royalty])

  (defcap INTERMEDIARY ()
    true
  )

  (defun require-INTERMEDIARY ()
    (require-capability (INTERMEDIARY))
  )

  (defun create-INTERMEDIARY-guard:guard ()
    (create-user-guard (require-INTERMEDIARY))
  )

  (defun get-INTERMEDIARY-account:string ()
    (create-principal (create-INTERMEDIARY-guard))
  )
  
  (defconst ROYALTY:string "ROYALTY")
  (deftable token-royalties:{token-royalty})

  (defun update-token-royalties:string 
    (
      token-id:string
      royalties:[object{royalty}]
    )
    @doc "Updates the royalties for the token"

    (with-capability (OPS)
      (write royalties ROYALTY
        { "token-id": ROYALTY
        , "royalties": royalties 
        }
      )
    )
  )

  (defun get-royalties-for-token:[object:{royalty}] (token-id:string)
    (at "royalties" (read token-royalties token-id ["royalties"]))
  )

  ;; -------------------------------
  ;; Policy

  (implements kip.token-policy-v1)
  (use kip.token-policy-v1 [token-info])

  (defschema policy-schema
    fungible:module{fungible-v2}
    creator:string
    creator-guard:guard
    royalty-rate:decimal
  )

  (deftable policies:{policy-schema})

  (defconst QUOTE-MSG-KEY "quote"
    @doc "Payload field for quote spec")

  (defschema quote-spec
    @doc "Quote data to include in payload"
    fungible:module{fungible-v2}
    price:decimal
    recipient:string
    recipient-guard:guard
  )

  (defschema quote-schema
    id:string
    spec:object{quote-spec})

  (deftable quotes:{quote-schema})

  (defun get-policy:object{policy-schema} (token:object{token-info})
    (read policies (at 'id token))
  )

  (defcap OFFER:bool
    ( sale-id:string
      token-id:string
      amount:decimal
      price:decimal
      royalty-payout:decimal
      spec:object{quote-spec}
    )
    @doc "For event emission purposes"
    @event
    true
  )

  (defun enforce-ledger:bool ()
    (enforce-guard (marmalade.ledger.ledger-guard))
  )

  (defun enforce-init:bool
    ( token:object{token-info}
    )
    (enforce-ledger)
    true
  )

  (defun enforce-mint:bool
    ( token:object{token-info}
      account:string
      guard:guard
      amount:decimal
    )
    (enforce-ledger)
    (enforce-guard (free.tiki-perms.get-ops-guard))
  )

  (defun enforce-burn:bool
    ( token:object{token-info}
      account:string
      amount:decimal
    )
    (enforce-ledger)
    (enforce (get-bool-value CAN_BURN) "No burning")
  )

  (defun enforce-offer:bool
    ( token:object{token-info}
      seller:string
      amount:decimal
      sale-id:string )
    (enforce-ledger)
    (enforce-sale-pact sale-id)

    (marmalade.ledger.enforce-unit (at "id" token) amount)

    (let* 
      ( 
        (spec:object{quote-spec} (read-msg QUOTE-MSG-KEY))
        (price:decimal (at 'price spec))
        (recipient:string (at 'recipient spec))
        (recipient-guard:guard (at 'recipient-guard spec))
        (recipient-details:object (fungible::details recipient))
        (sale-price:decimal (* amount price))
        (royalty-payout:decimal
          (floor 
            (* sale-price (get-royalty-percent)) 
            (fungible::precision)
          )
        )
      )
      (fungible::enforce-unit sale-price)
      (enforce (< 0.0 price) "Offer price must be positive")
      (enforce (=
        (at 'guard recipient-details) recipient-guard)
        "Recipient guard does not match"
      )
      (insert quotes sale-id 
        { 'id: (at 'id token)
        , 'spec: spec 
        }
      )
      (emit-event (QUOTE sale-id (at 'id token) amount sale-price royalty-payout spec))
    )
    true
  )

  (defun enforce-buy:bool
    ( token:object{token-info}
      seller:string
      buyer:string
      buyer-guard:guard
      amount:decimal
      sale-id:string )
    (enforce-ledger)
    (enforce-sale-pact sale-id)

    (with-read quotes sale-id 
      { 'id:= qtoken
      , 'spec:= spec:object{quote-spec} 
      }
      (enforce (= qtoken (at 'id token)) "incorrect sale token")
      (bind spec
        { 'price := price:decimal
        , 'recipient := recipient:string
        , 'fungible := fungible:module{fungible-v2}
        }
        (let* 
          (
            (sale-price:decimal (* amount price))
            (royalty-data:decimal (get-royalty-data))
            (royalty-payout:decimal
              (floor (* sale-price (at "percent" royalty-data)) (fungible::precision)))
            (payout:decimal (- sale-price royalty-payout)) 
          )
          (if (> royalty-payout 0.0)
            (fungible::transfer buyer (at "account" royalty-data) royalty-payout)
            "No royalty"
          )
          (fungible::transfer buyer recipient payout)
        )
      )
      true
    )
  )

  (defun enforce-sale-pact:bool (sale:string)
    "Enforces that SALE is id for currently executing pact"
    (enforce (= sale (pact-id)) "Invalid pact/sale id")
  )

  (defun enforce-transfer:bool
    ( token:object{token-info}
      sender:string
      guard:guard
      receiver:string
      amount:decimal )
    (enforce-ledger)
    (enforce (get-bool-value CAN_TRANSFER) "No transfers")
  )

  (defun enforce-crosschain:bool
    ( token:object{token-info}
      sender:string
      guard:guard
      receiver:string
      target-chain:string
      amount:decimal )
    (enforce-ledger)
    (enforce (get-bool-value CAN_XCHAIN) "No crosschain transfers")
  )
)


(if (read-msg "init")
  [
    (create-table m-guards)
    (create-table bool-values)
    (init-perms (read-keyset "gov") (read-keyset "ops"))
    (update-bool-value CAN_BURN (read-msg "can-burn"))
    (update-bool-value CAN_TRANSFER (read-msg "can-transfer"))
    (update-bool-value CAN_XCHAIN (read-msg "can-xchain"))
    (init-royalty 
      (read-msg "royalty-account")
      (read-msg "royalty-percent")
      (read-msg "royalty-guard")  
    )
  ]
  "Contract upgraded"
)