(define-data-var issuer principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)  ;; Government issuer address (deployer)
(define-data-var sukuk-name (string-ascii 32) "Government Sukuk Fund")
(define-data-var sukuk-symbol (string-ascii 8) "GSUKUK")
(define-data-var sukuk-total-supply uint u0)   ;; Total sukuk issued
(define-data-var sukuk-price uint u1000000)     ;; Price per sukuk in micro-STX (1 STX = 1,000,000 micro-STX)
(define-data-var sukuk-maturity (response uint uint) (ok u0)) ;; Maturity timestamp
(define-data-var total-subscribed uint u0)     ;; Total STX collected

;; Map: subscriber principal => {amount-sukuk: uint, stx-paid: uint}
(define-map subscribers {account: principal} {amount-sukuk: uint, stx-paid: uint})

(define-constant ERR_NOT_ISSUER (err u100))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u101))
(define-constant ERR_NO_SUBSCRIPTION (err u102))
(define-constant ERR_NOT_MATURED (err u103))
(define-constant ERR_ALREADY_SET_MATURITY (err u104))

;; Helper: only issuer
(define-private (assert-issuer)
  (if (is-eq tx-sender (var-get issuer))
      (ok true)
      ERR_NOT_ISSUER))

;; Set sukuk parameters: maturity timestamp, total supply
(define-public (configure-sukuk (maturity-block-height uint) (total-supply uint))
  (begin
    (try! (assert-issuer))
    ;; maturity can only be set once - check if already set (ok means set, err means not set)
    (match (var-get sukuk-maturity)
      ok-val ERR_ALREADY_SET_MATURITY
      err-val (ok (begin
        (var-set sukuk-maturity (ok maturity-block-height))
        (var-set sukuk-total-supply total-supply)
        true)))))

;; Public subscription: send STX and receive sukuk units
(define-public (subscribe-sukuk)
  (let (
        (price (var-get sukuk-price))
        (sent (stx-transfer? price tx-sender (as-contract tx-sender)))
       )
    (begin
      (unwrap! sent ERR_INSUFFICIENT_PAYMENT)
      (let (
            (current-subscribed (var-get total-subscribed))
            (new-total (+ current-subscribed price))
            (unit-count u1) ;; always 1 sukuk per price
          )
        (var-set total-subscribed new-total)
        (match (map-get? subscribers {account: tx-sender})
          entry (begin
                   (map-set subscribers {account: tx-sender}
                     { amount-sukuk: (+ (get amount-sukuk entry) unit-count)
                     , stx-paid:    (+ (get stx-paid entry) price) })
                   (ok unit-count))
          (begin
            (map-insert subscribers {account: tx-sender}
               { amount-sukuk: unit-count, stx-paid: price })
            (ok unit-count))
        )
      )
    )
  )
)

;; Check maturity
(define-read-only (is-matured)
  (match (var-get sukuk-maturity)
    ok-val (>= stacks-block-height ok-val)
    err-val false))

;; Redeem sukuk after maturity: investor gets STX back plus profit share
(define-public (redeem)
  (if (not (is-matured))
      ERR_NOT_MATURED
      (let ((caller tx-sender))
        (let ((entry-opt (map-get? subscribers {account: caller})))
          (match entry-opt
            entry (let (
                        (units (get amount-sukuk entry))
                        (paid (get stx-paid entry))
                        ;; simple profit: 5% on principal
                        (profit (/ (* paid u5) u100))
                        (payout (+ paid profit))
                        (transfer-resp (as-contract (stx-transfer? payout tx-sender caller)))
                      )
                    (if (is-err transfer-resp)
                        ERR_INSUFFICIENT_PAYMENT
                        (begin
                          ;; clear subscription
                          (map-delete subscribers {account: caller})
                          (ok payout)
                        )
                    )
                  )
            ERR_NO_SUBSCRIPTION
          )
        )
      )
  )
)

;; View functions
(define-read-only (get-subscriber (acct principal))
  (map-get? subscribers {account: acct}))

(define-read-only (get-total-subscribed)
  (var-get total-subscribed))

(define-read-only (get-terms)
  { name: (var-get sukuk-name), symbol: (var-get sukuk-symbol), price: (var-get sukuk-price), maturity: (var-get sukuk-maturity) })
