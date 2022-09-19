(interface supply-control-v1
  (defun burn:decimal (purpose:string account:string amount:decimal))
  (defun mint:decimal (purpose:string account:string guard:guard amount:decimal))
  (defun total-supply:decimal ())
)
