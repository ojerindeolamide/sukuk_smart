;; Sukuk Smart Contract - Islamic Finance Sukuk Token on Stacks

;; Government issuer address - using standard test address
(define-data-var issuer principal 'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5)

;; Sukuk metadata
(define-data-var sukuk-name (string-ascii 32) "Government Sukuk Fund")
(define-data-var sukuk-symbol (string-ascii 8) "GSUKUK")
(define-data-var sukuk-total-supply uint u0)   ;; Total sukuk issued
(define-data-var sukuk-price uint u1000000)    ;; Price per sukuk in micro-STX (1 STX = 1,000,000 micro-STX)
(define-data-var sukuk-maturity uint u0)       ;; Maturity block height
(define-data-var maturity-set bool false)      ;; Track if maturity has been set
(define-data-var total-subscribed uint u0)     ;; Total STX collected

;; Map: subscriber principal => {amount-sukuk: uint, stx-paid: uint}
(define-map subscribers {account: principal} {amount-sukuk: uint, stx-paid: uint})

;; Error codes
(define-constant ERR_NOT_ISSUER u100)
(define-constant ERR_INSUFFICIENT_PAYMENT u101)
(define-constant ERR_NO_SUBSCRIPTION u102)
(define-constant ERR_NOT_MATURED u103)
(define-constant ERR_ALREADY_SET_MATURITY u104)
(define-constant ERR_TRANSFER_FAILED u105)

;; Helper: only issuer can call
(define-private (assert-issuer)
  (begin
    (asserts! (is-eq tx-sender (var-get issuer)) (err ERR_NOT_ISSUER))
    (ok true)))

;; Set sukuk parameters: maturity block height, total supply
(define-public (configure-sukuk (maturity-block-height uint) (total-supply uint))
  (begin
    (try! (assert-issuer))
    ;; maturity can only be set once
    (asserts! (not (var-get maturity-set)) (err ERR_ALREADY_SET_MATURITY))
    (var-set sukuk-maturity maturity-block-height)
    (var-set sukuk-total-supply total-supply)
    (var-set maturity-set true)
    (ok true)))

;; Public subscription: send STX and receive sukuk units
(define-public (subscribe-sukuk)
  (let (
        (price (var-get sukuk-price))
        (sender tx-sender)
       )
    (begin
      ;; Transfer STX from sender to contract
      (try! (stx-transfer? price sender (as-contract tx-sender)))
      (let (
            (current-subscribed (var-get total-subscribed))
            (new-total (+ current-subscribed price))
            (unit-count u1) ;; 1 sukuk per price unit
          )
        (var-set total-subscribed new-total)
        (match (map-get? subscribers {account: sender})
          entry (begin
                   (map-set subscribers {account: sender}
                     { amount-sukuk: (+ (get amount-sukuk entry) unit-count)
                     , stx-paid:    (+ (get stx-paid entry) price) })
                   (ok unit-count))
          (begin
                  (map-insert subscribers {account: sender}
                     { amount-sukuk: unit-count, stx-paid: price })
                  (ok unit-count))
        )
      )
    )
  )
)

;; Check if sukuk has matured
(define-read-only (is-matured)
  (>= stacks-block-height (var-get sukuk-maturity)))

;; Redeem sukuk after maturity: investor gets STX back plus profit share
(define-public (redeem)
  (begin
    (asserts! (is-matured) (err ERR_NOT_MATURED))
    (let (
          (entry (map-get? subscribers {account: tx-sender}))
         )
      (asserts! (is-some entry) (err ERR_NO_SUBSCRIPTION))
      (let (
            (entry-data (unwrap! entry (err ERR_NO_SUBSCRIPTION)))
            (units (get amount-sukuk entry-data))
            (paid (get stx-paid entry-data))
            ;; simple profit: 5% on principal
            (profit (/ (* paid u5) u100))
            (payout (+ paid profit))
          )
        ;; Transfer STX from contract to investor
        (try! (as-contract (stx-transfer? payout (as-contract tx-sender) tx-sender)))
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
  { name: (var-get sukuk-name),
    symbol: (var-get sukuk-symbol),
    price: (var-get sukuk-price),
    maturity: (var-get sukuk-maturity),
    total-supply: (var-get sukuk-total-supply),
    issuer: (var-get issuer) })
