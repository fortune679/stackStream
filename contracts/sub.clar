;; Decentralized Content Subscription Platform

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_CREATOR_NOT_FOUND (err u102))
(define-constant ERR_INVALID_DURATION (err u103))
(define-constant ERR_SUBSCRIPTION_EXPIRED (err u104))
(define-constant ERR_ALREADY_CLAIMED (err u105))
(define-constant ERR_ALREADY_UNSUBSCRIBED (err u106))
(define-constant ERR_INVALID_NAME (err u107))
(define-constant ERR_INVALID_DESCRIPTION (err u108))
(define-constant ERR_CREATOR_ALREADY_EXISTS (err u109))
(define-constant ERR_PLATFORM_FEE_EXCEEDS_LIMIT (err u110))
(define-constant ERR_INVALID_PRINCIPAL (err u111))
(define-constant ERR_SUBSCRIPTION_NOT_FOUND (err u112))
(define-constant ERR_INVALID_TIER_PRICE (err u113))
(define-constant ERR_TIER_NOT_FOUND (err u114))
(define-constant ERR_ALREADY_SUBSCRIBED (err u115))

;; Data variables
(define-data-var contract-owner principal tx-sender)
(define-data-var platform-fee-percent uint u5) ;; 5% platform fee
(define-data-var platform-treasury uint u0)

;; Data maps
(define-map creators
  { creator-id: uint }
  {
    address: principal,
    name: (string-utf8 50),
    description: (string-utf8 500),
    total-subscribers: uint,
    earnings: uint,
    claimed-earnings: uint
  }
)

(define-map creator-tiers
  { creator-id: uint, tier-id: uint }
  {
    name: (string-utf8 50),
    description: (string-utf8 200),
    price-per-month: uint,
    benefits: (string-utf8 500)
  }
)

(define-map subscriptions
  { creator-id: uint, subscriber: principal, tier-id: uint }
  {
    start-block: uint,
    end-block: uint,
    amount-paid: uint,
    active: bool
  }
)

(define-map creator-by-address
  { address: principal }
  { creator-id: uint }
)

(define-data-var next-creator-id uint u1)

;; Private functions
(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-percent)) u100))

(define-private (is-valid-principal (address principal))
  (not (is-eq address 'SP000000000000000000002Q6VF78)))

(define-private (blocks-per-month)
  u4320) ;; ~30 days assuming 10 minute blocks

;; Public functions
(define-public (register-creator 
    (name (string-utf8 50)) 
    (description (string-utf8 500))
  )
  (let (
    (creator-id (var-get next-creator-id))
  )
    (asserts! (and (> (len name) u0) (<= (len name) u50)) ERR_INVALID_NAME)
    (asserts! (and (> (len description) u0) (<= (len description) u500)) ERR_INVALID_DESCRIPTION)
    (asserts! (is-none (map-get? creator-by-address { address: tx-sender })) ERR_CREATOR_ALREADY_EXISTS)
    
    ;; Create new creator
    (map-set creators { creator-id: creator-id }
      {
        address: tx-sender,
        name: name,
        description: description,
        total-subscribers: u0,
        earnings: u0,
        claimed-earnings: u0
      }
    )
    
    ;; Map creator address to ID
    (map-set creator-by-address { address: tx-sender } { creator-id: creator-id })
    
    ;; Increment creator ID counter
    (var-set next-creator-id (+ creator-id u1))
    
    (print { event: "creator-registered", creator-id: creator-id, address: tx-sender })
    (ok creator-id)))

(define-public (add-subscription-tier 
    (tier-id uint)
    (name (string-utf8 50))
    (description (string-utf8 200))
    (price-per-month uint)
    (benefits (string-utf8 500))
  )
  (let (
    (creator-info (unwrap! (map-get? creator-by-address { address: tx-sender }) ERR_CREATOR_NOT_FOUND))
    (creator-id (get creator-id creator-info))
    (tier-key { creator-id: creator-id, tier-id: tier-id })
  )
    (asserts! (and (> (len name) u0) (<= (len name) u50)) ERR_INVALID_NAME)
    (asserts! (and (> (len description) u0) (<= (len description) u200)) ERR_INVALID_DESCRIPTION)
    (asserts! (> price-per-month u0) ERR_INVALID_TIER_PRICE)
    
    ;; Create new subscription tier
    (map-set creator-tiers tier-key
      {
        name: name,
        description: description,
        price-per-month: price-per-month,
        benefits: benefits
      }
    )
    
    (print { 
      event: "tier-added", 
      creator-id: creator-id, 
      tier-id: tier-id, 
      price: price-per-month 
    })
    
    (ok tier-id)))

(define-public (renew-subscription (creator-id uint) (tier-id uint) (months uint))
  (let (
    (creator (unwrap! (map-get? creators { creator-id: creator-id }) ERR_CREATOR_NOT_FOUND))
    (tier (unwrap! (map-get? creator-tiers { creator-id: creator-id, tier-id: tier-id }) ERR_TIER_NOT_FOUND))
    (subscription-key { creator-id: creator-id, subscriber: tx-sender, tier-id: tier-id })
    (subscription (unwrap! (map-get? subscriptions subscription-key) ERR_SUBSCRIPTION_NOT_FOUND))
    (price-per-month (get price-per-month tier))
    (total-amount (* price-per-month months))
    (platform-fee (calculate-platform-fee total-amount))
    (creator-amount (- total-amount platform-fee))
    (blocks-duration (* months (blocks-per-month)))
    (current-block block-height)
    (new-end-block (+ (get end-block subscription) blocks-duration))
  )
    (asserts! (> months u0) ERR_INVALID_DURATION)
    (asserts! (get active subscription) ERR_ALREADY_UNSUBSCRIBED)
    
    ;; Transfer STX from subscriber to contract
    (match (stx-transfer? (+ total-amount platform-fee) tx-sender (as-contract tx-sender))
      success (begin
        ;; Update creator earnings
        (map-set creators { creator-id: creator-id }
          (merge creator { 
            earnings: (+ (get earnings creator) creator-amount)
          })
        )
        
        ;; Update subscription record
        (map-set subscriptions subscription-key
          (merge subscription { 
            end-block: new-end-block,
            amount-paid: (+ (get amount-paid subscription) total-amount)
          })
        )
        
        ;; Add platform fee to treasury
        (var-set platform-treasury (+ (var-get platform-treasury) platform-fee))
        
        (print { 
          event: "subscription-renewed", 
          creator-id: creator-id, 
          subscriber: tx-sender, 
          tier-id: tier-id,
          months: months,
          amount: total-amount,
          new-end-block: new-end-block
        })
        
        (ok true))
      error (err error))))

(define-public (cancel-subscription (creator-id uint) (tier-id uint))
  (let (
    (subscription-key { creator-id: creator-id, subscriber: tx-sender, tier-id: tier-id })
    (subscription (unwrap! (map-get? subscriptions subscription-key) ERR_SUBSCRIPTION_NOT_FOUND))
  )
    (asserts! (get active subscription) ERR_ALREADY_UNSUBSCRIBED)
    
    ;; Mark subscription as inactive
    (map-set subscriptions subscription-key
      (merge subscription { active: false })
    )
    
    (print { 
      event: "subscription-cancelled", 
      creator-id: creator-id, 
      subscriber: tx-sender, 
      tier-id: tier-id
    })
    
    (ok true)))

(define-public (claim-earnings (creator-id uint))
  (let (
    (creator-info (unwrap! (map-get? creator-by-address { address: tx-sender }) ERR_CREATOR_NOT_FOUND))
    (creator-id-from-map (get creator-id creator-info))
    (creator (unwrap! (map-get? creators { creator-id: creator-id }) ERR_CREATOR_NOT_FOUND))
    (earnings (get earnings creator))
    (claimed-earnings (get claimed-earnings creator))
    (available-earnings (- earnings claimed-earnings))
  )
    (asserts! (is-eq creator-id creator-id-from-map) ERR_UNAUTHORIZED)
    (asserts! (> available-earnings u0) ERR_INVALID_AMOUNT)
    
    ;; Transfer funds to creator
    (match (as-contract (stx-transfer? available-earnings tx-sender tx-sender))
      success (begin
        ;; Update claimed earnings
        (map-set creators { creator-id: creator-id }
          (merge creator { claimed-earnings: earnings })
        )
        
        (print { 
          event: "earnings-claimed", 
          creator-id: creator-id, 
          address: tx-sender, 
          amount: available-earnings
        })
        
        (ok available-earnings))
      error (err error))))

;; Admin functions
(define-public (withdraw-platform-fees)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (let ((balance (var-get platform-treasury)))
      (asserts! (> balance u0) ERR_INVALID_AMOUNT)
      (match (as-contract (stx-transfer? balance tx-sender (var-get contract-owner)))
        success (begin
          (var-set platform-treasury u0)
          (print { event: "platform-fees-withdrawn", amount: balance })
          (ok balance))
        error (err error)))))

(define-public (set-platform-fee-percent (percent uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= percent u20) ERR_PLATFORM_FEE_EXCEEDS_LIMIT) ;; Maximum 20% platform fee
    (ok (var-set platform-fee-percent percent))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-valid-principal new-owner) ERR_INVALID_PRINCIPAL)
    (ok (var-set contract-owner new-owner))))

;; Read-only functions
(define-read-only (get-creator-details (creator-id uint))
  (match (map-get? creators { creator-id: creator-id })
    creator (ok creator)
    ERR_CREATOR_NOT_FOUND))

(define-read-only (get-creator-by-address (address principal))
  (match (map-get? creator-by-address { address: address })
    creator-info (ok creator-info)
    (err ERR_CREATOR_NOT_FOUND)))

(define-read-only (get-tier-details (creator-id uint) (tier-id uint))
  (match (map-get? creator-tiers { creator-id: creator-id, tier-id: tier-id })
    tier (ok tier)
    ERR_TIER_NOT_FOUND))

(define-read-only (get-subscription (creator-id uint) (subscriber principal) (tier-id uint))
  (match (map-get? subscriptions { creator-id: creator-id, subscriber: subscriber, tier-id: tier-id })
    subscription (ok subscription)
    ERR_SUBSCRIPTION_NOT_FOUND))

(define-read-only (is-subscribed (creator-id uint) (subscriber principal) (tier-id uint))
  (match (map-get? subscriptions { creator-id: creator-id, subscriber: subscriber, tier-id: tier-id })
    subscription (ok (and 
                      (get active subscription) 
                      (>= (get end-block subscription) block-height)))
    (ok false)))

(define-read-only (get-platform-fee-percent)
  (var-get platform-fee-percent))

(define-read-only (get-creator-count)
  (- (var-get next-creator-id) u1))