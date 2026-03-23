;; Government issuer address - using deployer as issuer
(define-constant issuer tx-sender)

;; Sukuk configuration constants
(define-constant sukuk-name "Government Sukuk Fund")
(define-constant sukuk-symbol "GSUKUK")
(define-constant sukuk-price u1000000)  ;; Price per sukuk in micro-STX (1 STX = 1,000,000 micro-STX)

;; Mutable state
(define-data-var sukuk-total-supply uint u0)   ;; Total sukuk issued
(define-data-var sukuk-maturity (optional uint) none) ;; Maturity block height
(define-data-var total-subscribed uint u0)     ;; Total STX collected

;; Map: subscriber principal => {amount-sukuk: uint, stx-paid: uint}
(define-map subscribers {account: principal} {amount-sukuk: uint, stx-paid: uint})

;; Error constants
(define-constant ERR_NOT_ISSUER (err u100))
(define-constant ERR_INSUFFICIENT_PAYMENT (err u101))
(define-constant ERR_NO_SUBSCRIPTION (err u102))
(define-constant ERR_NOT_MATURED (err u103))
(define-constant ERR_ALREADY_SET_MATURITY (err u104))

;; Private helper: check if caller is issuer
(define-private (is-issuer)
  (is-eq tx-sender issuer))

;; Set sukuk parameters: maturity timestamp, total supply
(define-public (configure-sukuk (maturity-block-height uint) (total-supply uint))
  (begin
    (asserts! (is-issuer) ERR_NOT_ISSUER)
    ;; maturity can only be set once
    (asserts! (is-none (var-get sukuk-maturity)) ERR_ALREADY_SET_MATURITY)
    ;; Validate inputs: maturity must be in the future, supply must be positive
    (asserts! (> maturity-block-height stacks-block-height) ERR_NOT_MATURED)
    (asserts! (> total-supply u0) ERR_NO_SUBSCRIPTION)
    (var-set sukuk-maturity (some maturity-block-height))
    (var-set sukuk-total-supply total-supply)
    (ok true)))

;; Public subscription: send STX and receive sukuk units
(define-public (subscribe-sukuk)
  (let (
        (price sukuk-price)
        (sent (stx-transfer? price tx-sender (as-contract tx-sender)))
       )
    (begin
      (asserts! (is-ok sent) ERR_INSUFFICIENT_PAYMENT)
      (let (
            (current-subscribed (var-get total-subscribed))
            (new-total (+ current-subscribed price))
            (unit-count u1) ;; 1 sukuk per price payment
          )
        (var-set total-subscribed new-total)
        (var-set sukuk-total-supply (+ (var-get sukuk-total-supply) unit-count))
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
    m (>= stacks-block-height m)
    false))

;; Redeem sukuk after maturity: investor gets STX back plus profit share
(define-public (redeem)
  (begin
    (asserts! (is-matured) ERR_NOT_MATURED)
    (let (
          (entry (map-get? subscribers {account: tx-sender}))
         )
      (asserts! (is-some entry) ERR_NO_SUBSCRIPTION)
      (let (
            (subscriber-data (unwrap! entry ERR_NO_SUBSCRIPTION))
            (paid (get stx-paid subscriber-data))
            ;; simple profit: 5% on principal
            (profit (/ (* paid u5) u100))
            (payout (+ paid profit))
            (transfer-resp (as-contract (stx-transfer? payout tx-sender tx-sender)))
          )
        (try! transfer-resp)
        ;; clear subscription
        (map-delete subscribers {account: tx-sender})
        (ok payout)
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
  { name: sukuk-name, symbol: sukuk-symbol, price: sukuk-price, maturity: (var-get sukuk-maturity) })
