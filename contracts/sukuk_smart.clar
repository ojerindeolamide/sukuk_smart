(define-data-var issuer principal 'SP3FBR2AGKJH9Q3D21D3XDS5SQGXYRBQBDG9EHWKY)  ;; Government issuer address
(define-data-var sukuk-name (string-ascii 32) "Government Sukuk Fund")
(define-data-var sukuk-symbol (string-ascii 8) "GSUKUK")
(define-data-var sukuk-total-supply uint u0)   ;; Total sukuk issued
(define-data-var sukuk-price uint u1000000)     ;; Price per sukuk in micro-STX (1 STX = 1,000,000 micro-STX)
(define-data-var sukuk-maturity (response uint uint) (err u0)) ;; Maturity timestamp (err = not set)
(define-data-var total-subscribed uint u0)     ;; Total STX collected

;; Map: subscriber principal => {amount-sukuk: uint, stx-paid: uint}
(define-map subscribers {account: principal} {amount-sukuk: uint, stx-paid: uint})

(define-constant ERR_NOT_ISSUER u100)
(define-constant ERR_INSUFFICIENT_PAYMENT u101)
(define-constant ERR_NO_SUBSCRIPTION u102)
(define-constant ERR_NOT_MATURED u103)
(define-constant ERR_ALREADY_SET_MATURITY u104)

;; Helper: only issuer
(define-private (assert-issuer) (begin
  (asserts! (is-eq tx-sender (var-get issuer)) ERR_NOT_ISSUER)
  true))

;; Set sukuk parameters: maturity timestamp, total supply
(define-public (configure-sukuk (maturity-block-height uint) (total-supply uint))
  (begin
    (assert-issuer)
    ;; maturity can only be set once
    (match (var-get sukuk-maturity)
      (ok _) (err ERR_ALREADY_SET_MATURITY)
      (err _) (begin
        (var-set sukuk-maturity (ok maturity-block-height))
        (var-set sukuk-total-supply total-supply)
        (ok true)))))

;; Public subscription: send STX and receive sukuk units
(define-public (subscribe-sukuk)
  (let (
        (price (var-get sukuk-price))
        (sent (stx-transfer? price tx-sender (as-contract tx-sender)))
       )
    (begin
      (asserts! (is-ok sent) ERR_INSUFFICIENT_PAYMENT)
      (let (
            (current-subscribed (var-get total-subscribed))
            (new-total (+ current-subscribed price))
            (unit-count (/ price price)) ;; always 1 sukuk per price
          )
        (var-set total-subscribed new-total)
        (match (map-get subscribers {account: tx-sender})
          entry (begin
                   (map-set subscribers {account: tx-sender}
                     { amount-sukuk: (+ (get amount-sukuk entry) unit-count)
                     , stx-paid:    (+ (get stx-paid entry) price) })
                   (ok unit-count))
          none  (begin
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
    (ok m) (>= block-height m)
    (err _) false)

;; Redeem sukuk after maturity: investor gets STX back plus profit share
(define-public (redeem)
  (begin
    (asserts! (is-matured) ERR_NOT_MATURED)
    (let (
          (entry (map-get subscribers {account: tx-sender}))
         )
      (asserts! (is-some entry) ERR_NO_SUBSCRIPTION)
      (let (
            {amount-sukuk: units, stx-paid: paid} (unwrap! entry (err ERR_NO_SUBSCRIPTION))
            ;; simple profit: 5% on principal
            (profit (/ (* paid u5) u100))
            (payout (+ paid profit))
            (transfer-resp (stx-transfer? payout (as-contract tx-sender) tx-sender))
          )
        (asserts! (is-ok transfer-resp) transfer-resp)
        ;; clear subscription
        (map-delete subscribers {account: tx-sender})
        (ok payout)
      )
    )
  )
)

;; View functions
(define-read-only (get-subscriber (acct principal))
  (map-get subscribers {account: acct}))

(define-read-only (get-total-subscribed)
  (var-get total-subscribed))

(define-read-only (get-terms)
  { name: (var-get sukuk-name), symbol: (var-get sukuk-symbol), price: (var-get sukuk-price), maturity: (var-get sukuk-maturity) })
