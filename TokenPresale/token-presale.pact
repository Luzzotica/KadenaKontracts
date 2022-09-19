(namespace "free")

(define-keyset "free.token-bank-admin" (read-keyset "token-bank-admin"))
(define-keyset "free.token-sale-gov" (read-keyset "token-sale-gov"))
(define-keyset "free.token-sale-ops2" (read-keyset "token-sale-ops"))

(module token-sale-manager GOV

  ; Custom Values: Token name, guards, accounts
  (defconst KDA_BANK_ACCOUNT:string "token-sale-bank" )
  (defconst KDA_BANK_GUARD_NAME:string "free.token-bank-admin" )
  (defconst GOV_GUARD_NAME:string "free.token-sale-gov")
  (defconst OPS_GUARD_NAME:string "free.token-sale-ops" )
  (defun kda-bank-guard () (create-module-guard KDA_BANK_GUARD_NAME))
  (defconst TOKEN_NAME:string "REPLACE_WITH_YOURS" )

  (use coin)

  ;; -------------------------------
  ;; Schemas and Tables

  (defschema whitelist ;; ID is account
    account:string
    guard:guard
    deleted:bool)

  (defschema sale ;; ID is name
    name:string
    tokenName:string
    type:string
    startDate:time
    endDate:time
    tokenLimitPerAccount:decimal
    tokenSaleSupply:decimal
    tokenPerKda:decimal
    status:string
    private:bool)

  (defschema reservation ;; ID is account-txid
    sale:string
    account:string
    guard:guard
    timestamp:time
    usedToken:string
    amountUsedToken:decimal
    amountToken:decimal
    status:string)

  (defschema cumulativeTokenSaleAmount ;; ID is related sale's name
    cumulativeAmount:decimal)

  (deftable whitelists:{whitelist})
  (deftable sales:{sale})
  (deftable reservations:{reservation})
  (deftable cumulativeTokenSaleAmounts:{cumulativeTokenSaleAmount})

  ;; -------------------------------
  ;; Constants

  ;  Sale types
  (defconst ON-CHAIN:string 'on-chain )
  (defconst OFF-CHAIN:string 'off-chain )

  ;  Sale statuses
  (defconst CREATED:string 'created )
  (defconst CANCELED:string 'canceled )
  (defconst SUCCEEDED:string 'succeeded )
  (defconst FAILED:string 'failed )

  ;  Reservation statuses
  (defconst STATUS_REQUESTED:string 'requested )
  (defconst STATUS_APPROVED:string 'approved )
  (defconst STATUS_REJECTED:string 'rejected )

  ;; -------------------------------
  ;; Capabilities

  (defcap GOV ()
    (enforce-guard GOV_GUARD_NAME)
  )

  (defcap OPS ()
    (enforce-guard OPS_GUARD_NAME)
  )

  (defcap RESERVE
    ( sale:string
      timestamp:time
      saleType:string)
    "Reserve event for token reservation"
    @event
    (with-read sales sale
      {
      "type" := type,
      "status" := status,
      "startDate" := startDate,
      "endDate" := endDate
      }
      (enforce (= type saleType) "Wrong sale type")
      (enforce (= status CREATED) "Sale status not created")
      (enforce (>= timestamp startDate) "Sale hasn't started yet")
      (enforce (<= timestamp endDate) "Sale hasn't ended yet")
   )
  )

  (defcap RESERVE_REQUIREMENTS (sale:string account:string amountToken:decimal)
    (let
      (
        (availableSupply (available-supply sale))
        (availableAccountAllocation (token-allocation-account-available sale account))
      )
      (enforce (<= amountToken availableSupply) "Total supply exceeded")
      (enforce (<= amountToken availableAccountAllocation) "Total account allocation exceeded")
    )
  )

  ;; -------------------------------
  ;; Whitelisting

  (defun add-whitelist:string (account:string)
    @doc "Add account to whitelist"
    (with-capability (OPS)
      (let
        (
          (g (at 'guard (coin.details account)))
        )
        (insert whitelists account
          { "account"    : account
          , "guard"      : g
          , "deleted"    : false
          })
        (format "{} added to whitelist" [account])
      )
    )
  )

  (defun delete-from-whitelist:string (account:string)
    @doc   "Remove account from whitelist"
    (with-capability (OPS)
      (update whitelists account {"deleted":true})
      (format "{} deleted from whitelist" [account])
    )
  )

  ;; -------------------------------
  ;; Sale Handling

  (defun create-sale:string 
    (name:string
    type:string 
    startDate:time 
    endDate:time 
    tokenPerKda:decimal 
    tokenLimitPerAccount:decimal 
    tokenSaleSupply:decimal
    private:bool)
    @doc "Create sale with parameters, type is ON-CHAIN or OFF-CHAIN"
    (enforce (< 0.0 tokenPerKda) "TOKEN/KDA ratio is not a positive number")
    (enforce (< 0.0 tokenLimitPerAccount) "KTOKENDX limit per address is not a positive number")
    (enforce (< 0.0 tokenSaleSupply) "TOKEN sale supply is not a positive number")
    (enforce (or (= type ON-CHAIN) (= type OFF-CHAIN)) "Sale type not found")
    (with-capability (OPS)
      (insert cumulativeTokenSaleAmounts name
        { "cumulativeAmount": 0.0 })
      (insert sales name
        { "name"                  :name
        , "tokenName"             :TOKEN_NAME
        , "type"                  :type
        , "startDate"             :startDate
        , "endDate"               :endDate
        , "tokenPerKda"           :tokenPerKda
        , "tokenLimitPerAccount"  :tokenLimitPerAccount
        , "tokenSaleSupply"       :tokenSaleSupply
        , "private"               :private
        , "status"                :CREATED
        })
      (format "sale {} created for token {}" [name TOKEN_NAME])
    )
  )

  (defun end-sale:string (sale:string status:string)
    @doc "End sale by setting its status"
    (format "Status: {}, Const: {}, equals: {}" [status SUCCEEDED (= status SUCCEEDED)])
    (enforce (or (or (= status SUCCEEDED) (= status FAILED)) (= status CANCELED)) "Sale status not found")
    (with-capability (OPS)
      (update sales sale {
        "status": status
        }
      )
      (format "Updated sale status to {}" [status])
    )
  )

  ;; -------------------------------
  ;; Reserving

  (defun reserve-on-chain:string (sale:string account:string amountKda:decimal)
    @doc "Add reservation directly on-chain"
    (with-capability (RESERVE sale (curr-time) ON-CHAIN)
      (with-read sales sale {
        "tokenPerKda" := tokenPerKda,
        "private" := private,
        "status" := status
        }
        (enforce (= status CREATED) "Sale has ended")
        (let
          ( 
            (tx-id (hash {"sale": sale, "account": account, "amountKda": amountKda, "salt": (curr-time)}))
            (amountToken (* amountKda tokenPerKda))
            (whitelisted (is-account-whitelisted account))
            (guard (at 'guard (coin.details account)))
          )
          (if private
            (enforce whitelisted "Account not whitelisted")
            ""
          )
          
          (with-capability (RESERVE_REQUIREMENTS sale account amountToken)
            (coin.transfer account KDA_BANK_ACCOUNT amountKda)
            (insert reservations (format "{}-{}" [account, tx-id])
              { "sale"           : sale
              , "account"        : account
              , "usedToken"      : "KDA"
              , "amountUsedToken": amountKda
              , "amountToken"    : amountToken
              , "timestamp"      : (curr-time)
              , "guard"          : guard
              , "status"         : STATUS_REQUESTED
              })
              (with-read cumulativeTokenSaleAmounts sale
                { "cumulativeAmount" := cumulativeAmount }
                (update cumulativeTokenSaleAmounts sale {"cumulativeAmount": (+ cumulativeAmount amountToken)})
                )
            (format "{} reserved {} {} on {}" [account, amountToken, TOKEN_NAME, sale])
          )
        )
      )
    )
  )

  (defun reject-on-chain:string (reservation-id:string)
    @doc "Reject on-chain reservation with refund"
    (with-capability (OPS)
      (with-read reservations reservation-id
        { "sale"       := sale
        , "status"     := status
        , "amountUsedToken" := amount-kda
        , "account"    := account }
        (with-read sales sale
          { "type" := saleType }

          (enforce (= saleType ON-CHAIN) "sale type invalid")
          (enforce (= status STATUS_REQUESTED) "request is not open")
          (update reservations reservation-id
            { "status" : STATUS_REJECTED })
          (install-capability (coin.TRANSFER KDA_BANK_ACCOUNT account amount-kda))
          (coin.transfer KDA_BANK_ACCOUNT account amount-kda)
          (format "request {} rejected" [reservation-id])
        )
      )
    )
  )

  (defun reserve-off-chain:string (sale:string txHash:string account:string usedToken:string amountUsedToken:decimal amountToken:decimal timestamp:time)
    @doc "Add reservation handled off-chain"
    (with-capability (OPS)
      (with-capability (RESERVE sale timestamp OFF-CHAIN)
       (with-capability (RESERVE_REQUIREMENTS sale account amountToken)
         (let
           (
             (g (at 'guard (coin.details account)))
           )
           (insert reservations (format "{}-{}" [account, txHash])
             { "sale"           : sale
             , "account"        : account
             , "usedToken"      : usedToken
             , "amountUsedToken": amountUsedToken
             , "amountToken"      : amountToken
             , "timestamp"      : timestamp
             , "guard"          : g
             , "status"         : STATUS_REQUESTED
             })
             (with-read cumulativeTokenSaleAmounts sale{
               "cumulativeAmount":=cumulativeAmount
               }
               (update cumulativeTokenSaleAmounts sale {"cumulativeAmount": (+ cumulativeAmount amountToken)})
              )
           (format "{} reserved {} {} on {}" [account, amountToken, TOKEN_NAME, sale])
          )
        )
      )
    )
  )

  (defun reject-off-chain:string (reservation-id:string)
   @doc "Reject off-chain reservation - Refund will be handled off-chain"
    (with-capability (OPS)
      (with-read reservations reservation-id
        { "sale"       := sale
        , "status"     := status }
        (with-read sales sale
          {
            "type" := saleType
          }
          (enforce (= saleType OFF-CHAIN) "sale type invalid")
          (enforce (= status STATUS_REQUESTED) "request is not open")
          (update reservations reservation-id
            { "status" : STATUS_REJECTED })
          (format "request {} rejected" [reservation-id])
        )
      )
    )
  )

  ;; -------------------------------
  ;; Approving

  (defun approve:string (reservation-id:string)
    @doc "Approve reservation"

    (with-capability (OPS)
      (with-read reservations reservation-id
        { "status" := status }
        (enforce (= status STATUS_REQUESTED) "request is not open")
        (update reservations reservation-id
          { "status" : STATUS_APPROVED })
        (format "request {} approved" [reservation-id])
      )
    )
  )

  (defun approve-helper:string (reservation-id:string)
    @doc "Approve reservation if status is requested, otherwise do nothing."

    (require-capability (OPS))
    (with-read reservations reservation-id
      { "status" := status }
      (if (= status STATUS_REQUESTED)
        (update reservations reservation-id
          { "status" : STATUS_APPROVED })
        "skipping case"
      )
    )
  )

  (defun approve-all:string ()
    @doc "Approve all reservation using helper"

    (with-capability (OPS)
      (map (approve-helper) (get-tx-ids))
    )
  )

  ;; -------------------------------
  ;; Getters

  (defun fetch-reservations:[object{reservation}] (sale:string)
    @doc "Get all reservations for specified sale"

    (select reservations (where 'sale (= sale)))
  )

  (defun fetch-account-reservations:[object{reservation}] 
    (sale:string account:string)
    @doc "Get all account reservations for specified sale"

    (select reservations (and? (where 'sale (= sale)) (where 'account (= account))))
  )

  (defun token-reserved-account:decimal (sale:string account:string)
    @doc "Get total token reserved for account in specified sale"

    (fold (+) 0.0 (map (at 'amountToken ) (fetch-account-reservations sale account)))
  )

  (defun token-allocation-account-available:decimal (sale:string account:string)
    @doc "Get remaining token allocation for account in specified sale"

    (with-read sales sale
      { "tokenLimitPerAccount" := tokenLimitPerAccount
      }
      (- tokenLimitPerAccount (token-reserved-account sale account))
    )
  )

  (defun token-reserved:decimal (sale:string)
    @doc "Get total token reserved in specified sale"

    (at 'cumulativeAmount (read cumulativeTokenSaleAmounts sale))
  )

  (defun available-supply:decimal (sale:string)
    @doc "Get remaining token supply in specified sale"

    (with-read sales sale {
      "tokenSaleSupply" := tokenSaleSupply
      }
      (with-read cumulativeTokenSaleAmounts sale
        { "cumulativeAmount" := cumulativeAmount
        }
        (- tokenSaleSupply cumulativeAmount)
      )
    )
  )

  (defun total-supply:decimal (sale:string)
    @doc "Get token supply of specified sale"

    (at "tokenSaleSupply" (read sales sale))
  )

  (defun read-reservations 
    (account:string)

    (select reservations (where 'account (= account)))
  )

  (defun read-all-reservations ()
    (map (read reservations) (get-tx-ids))
  )

  (defun get-tx-ids ()
    (keys reservations)
  )

  (defun is-account-whitelisted:bool (account:string)
    @doc "Returns true if an account is whitelisted for the given sale, otherwise false"

    (with-default-read whitelists account 
      { "deleted": true }
      { "deleted" := deleted }
      (!= deleted true)
    )
  )

  (defun read-sale:object{sale} (sale:string)
    @doc "Returns sale object"

    (read sales sale)
  )

  (defun get-sale-price:decimal (sale:string)
    @doc "Gets the token amount per kda for the given sale"

    (at "tokenPerKda" (read sales sale))
  )

  ;; -------------------------------
  ;; Utils

  (defun curr-time:time ()
    @doc "Returns current chain's block-time in time type"

    (at 'block-time (chain-data))
  )
  
  ;; -------------------------------
  ;; Init

  (defun init ()
    (with-capability (GOV)
      (coin.create-account KDA_BANK_ACCOUNT (kda-bank-guard))
    )
  )
)


(if (read-msg "upgrade" )
  [
    (create-table whitelists)
    (create-table sales)
    (create-table reservations)
    (create-table cumulativeTokenSaleAmounts)
    (init)
  ]
  ["No upgrade"]
)