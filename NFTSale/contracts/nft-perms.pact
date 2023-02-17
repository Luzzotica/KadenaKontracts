(namespace "free")

(module nft-perms GOV
  @doc "This code is meant to be copy-pasted into a different smart contract."

  ;; -------------------------------
  ;; Governance and Permissions

  (defconst GOV_GUARD:string "gov")
  (defconst OPS_GUARD:string "ops")

  (defcap GOV ()
    (enforce-guard (at "guard" (read m-guards GOV_GUARD ["guard"])))
    (compose-capability (OPS_INTERNAL))
  )

  (defcap OPS ()
    (enforce-guard (at "guard" (read m-guards OPS_GUARD ["guard"])))
    (compose-capability (OPS_INTERNAL))
  )

  (defcap OPS_INTERNAL ()
    true
  )

  (defschema m-guard ;; ID is a const: OPS_GUARD, GOV_GUARD etc.
    @doc "Stores guards for the module"
    guard:guard  
  )
  (deftable m-guards:{m-guard})

  (defun rotate-gov:string (guard:guard)
    @doc "Requires GOV. Changes the gov guard to the provided one."

    (with-capability (GOV)
      (update m-guards GOV_GUARD
        { "guard": guard }  
      )

      "Rotated GOV to a new guard"
    )
  )

  (defun rotate-ops-from-gov (guard:guard)
    @doc "Requires GOV. Changes the ops guard to the provided one."

    (with-capability (GOV)
      (rotate-ops-internal guard)
    )
  )

  (defun rotate-ops:string (guard:guard)
    @doc "Requires OPS. Changes the ops guard to the provided one."

    (with-capability (OPS)
      (rotate-ops-internal guard)
    )
  )

  (defun rotate-ops-internal:string (guard:guard)
    @doc "Requires GOV. Changes the ops guard to the provided one."
    (require-capability (OPS_INTERNAL))

    (update m-guards OPS_GUARD
      { "guard": guard }
    )

    "Rotated OPS to a new guard"
  )

  (defun get-gov-guard:guard ()
    @doc "Gets the current gov guard and returns it"
    (at "guard" (read m-guards GOV_GUARD))
  )

  (defun get-ops-guard:guard ()
    @doc "Gets the current ops guard and returns it"
    (at "guard" (read m-guards OPS_GUARD))
  )

  (defun init-perms:string (gov:guard ops:guard)
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


(if (read-msg "upgrade")
  "Contract upgraded"
  [
    (create-table m-guards)
    (init-perms (read-keyset "gov") (read-keyset "ops"))
  ]
)