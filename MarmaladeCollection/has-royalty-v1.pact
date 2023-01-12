(namespace "free")

(interface has-royalty-v1
  
  (defschema royalty
    @doc "A royalty is a percentage of the sale price that is paid to the account."
    account:string
    percent:decimal
    guard:guard
  )

  (defschema token-royalty
    @doc "A token-royalty is a list of royalties that are paid to accounts. \
    \ This is used to create a table to track the royalties for each token \
    \ individually using the token-id. The table id is the token-id."
    token-id:string
    royalties:[object:{royalty}]
  )

  (defcap INTERMEDIARY ()
    @doc "The capability that must be installed to allow the contract to \
    \ install TRANSFER caps and distribute the royalties."
  )

  (defun require-INTERMEDIARY ()
    @doc "Requires that the INTERMEDIARY cap is installed."
  )

  (defun create-INTERMEDIARY-guard:guard ()
    @doc "Creates a new INTERMEDIARY guard."
  )

  (defun get-INTERMEDIARY-account:string ()
    @doc "Gets the intermediary account controlled by the contract \
    \ that will receive the sale price and then distribute the royalties."
  )

  (defun get-royalties-for-token:[object:{royalty}] (token-id:string)
    @doc "Gets the royalities for a token."
  )
)