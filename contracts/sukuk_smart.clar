(define-data-var issuer principal tx-sender)  ;; Government issuer address
(define-data-var sukuk-name (string-ascii 32) "Government Sukuk Fund")
(define-data-var sukuk-symbol (string-ascii 8) "GSUKUK")
(define-data-var sukuk-total-supply uint u0)   ;; Total sukuk issued
(define-data-var sukuk-price uint u1000000)     ;; Price per sukuk in micro-STX (1 STX = 1,000,000 micro-STX)
(define-data-var sukuk-maturity (optional uint) none) ;; Maturity timestamp
(define-data-var total-subscribed uint u0)     ;; Total STX collected

;; Map: subscriber principal => {amount-sukuk: uint, stx-paid: uint}
(define-map subscribers {account: principal} {amount-sukuk: uint, stx-paid: uint})

(define-constant ERR_NOT_ISSUER u100)
(define-constant ERR_INSUFFICIENT_PAYMENT u101)
(define-constant ERR_NO_SUBSCRIPTION u102)
(define-constant ERR_NOT_MATURED u103)
(define-constant ERR_ALREADY_SET_MATURITY u104)
(define-constant ERR_TRANSFER_FAILED u105)

;; Set sukuk parameters: maturity timestamp, total supply
(define-public (configure-sukuk (maturity-block-height uint) (total-supply uint))
  (begin
    ;; Only issuer can configure
    (asserts! (is-eq tx-sender (var-get issuer)) (err ERR_NOT_ISSUER))
    ;; maturity can only be set once
    (asserts! (is-none (var-get sukuk-maturity)) (err ERR_ALREADY_SET_MATURITY))
    (var-set sukuk-maturity (some maturity-block-height))
    (var-set sukuk-total-supply total-supply)
    (ok true)))

;; Public subscription: send STX and receive sukuk units
(define-public (subscribe-sukuk)
  (let (
        (price (var-get sukuk-price))
        (sent (stx-transfer? price tx-sender (as-contract tx-sender)))
       )
    (begin
      (asserts! (is-ok sent) (err ERR_INSUFFICIENT_PAYMENT))
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
    m (>= stacks-block-height m)
    false))

;; Redeem sukuk after maturity: investor gets STX back plus profit share
(define-public (redeem)
  (begin
    (asserts! (is-matured) (err ERR_NOT_MATURED))
    (let (
          (entry (map-get? subscribers {account: tx-sender}))
         )
      (asserts! (is-some entry) (err ERR_NO_SUBSCRIPTION))
      (let (
            (subscriber-data (unwrap! entry (err ERR_NO_SUBSCRIPTION)))
            (units (get amount-sukuk subscriber-data))
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
  { name: (var-get sukuk-name), symbol: (var-get sukuk-symbol), price: (var-get sukuk-price), maturity: (var-get sukuk-maturity) })
