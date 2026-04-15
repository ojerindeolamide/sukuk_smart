(define-constant issuer tx-sender)  ;; Government issuer address - set to deployer
(define-constant sukuk-name "Government Sukuk Fund")
(define-constant sukuk-symbol "GSUKUK")
(define-constant sukuk-price u1000000)     ;; Price per sukuk in micro-STX (1 STX = 1,000,000 micro-STX)
(define-data-var sukuk-total-supply uint u0)   ;; Total sukuk issued - used by configure-sukuk
(define-data-var sukuk-maturity (response uint uint) (ok u0)) ;; Maturity timestamp
(define-data-var total-subscribed uint u0)     ;; Total STX collected

;; Map: subscriber principal => {amount-sukuk: uint, stx-paid: uint}
(define-map subscribers {account: principal} {amount-sukuk: uint, stx-paid: uint})

(define-constant ERR_NOT_ISSUER (err u100))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u101))
(define-constant ERR_NO_SUBSCRIPTION (err u102))
(define-constant ERR_NOT_MATURED (err u103))
(define-constant ERR_ALREADY_SET_MATURITY (err u104))

;; Helper: only issuer - returns (ok true) or ERR_NOT_ISSUER
(define-private (assert-issuer)
  (if (is-eq tx-sender issuer)
      (ok true)
      ERR_NOT_ISSUER))

;; Set sukuk parameters: maturity timestamp, total supply
(define-public (configure-sukuk (maturity-block-height uint) (total-supply uint))
  (begin
    (try! (assert-issuer))
    ;; Validate inputs
    (asserts! (> maturity-block-height u0) (err u105))
    (asserts! (> total-supply u0) (err u106))
    ;; maturity can only be set once (check if currently 0)
    (let ((current-maturity (var-get sukuk-maturity)))
      (if (is-eq current-maturity (ok u0))
          (ok (begin
            (var-set sukuk-maturity (ok maturity-block-height))
            (var-set sukuk-total-supply total-supply)
            true))
          ERR_ALREADY_SET_MATURITY))))

;; Public subscription: send STX and receive sukuk units
(define-public (subscribe-sukuk)
  (let (
        (price sukuk-price)
        (sent (stx-transfer? price tx-sender (as-contract tx-sender)))
       )
    (begin
      (unwrap! sent ERR_INSUFFICIENT_PAYMENT)
      (let (
            (current-subscribed (var-get total-subscribed))
            (new-total (+ current-subscribed price))
            (unit-count u1) ;; always 1 sukuk per subscription
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
    m (if (is-eq m u0)
          false
          (>= stacks-block-height m))
    e false))

;; Redeem sukuk after maturity: investor gets STX back plus profit share
(define-public (redeem)
  (if (not (is-matured))
      ERR_NOT_MATURED
      (let (
            (entry (map-get? subscribers {account: tx-sender}))
           )
        (if (is-none entry)
            ERR_NO_SUBSCRIPTION
            (let (
                  (subscription (unwrap! entry ERR_NO_SUBSCRIPTION))
                  (paid (get stx-paid subscription))
                  ;; simple profit: 5% on principal
                  (profit (/ (* paid u5) u100))
                  (payout (+ paid profit))
                )
              (match (stx-transfer? payout (as-contract tx-sender) tx-sender)
                transfer-result (begin
                  (map-delete subscribers {account: tx-sender})
                  (ok payout))
                err-code (err err-code)
              )
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

(define-read-only (get-total-supply)
  (var-get sukuk-total-supply))

(define-read-only (get-terms)
  { name: sukuk-name, symbol: sukuk-symbol, price: sukuk-price, maturity: (var-get sukuk-maturity) })
