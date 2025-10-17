;; Title: Pet Care Matching Contract
;; Version: 1.0.0
;; Summary: Manages pet owner and caregiver matching with detailed requirements and qualifications
;; Description: Handles pet care service booking, scheduling, quality monitoring, feedback systems, and health records tracking

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))
(define-constant ERR_BOOKING_CONFLICT (err u104))
(define-constant ERR_INSUFFICIENT_RATING (err u105))
(define-constant ERR_PAYMENT_FAILED (err u106))
(define-constant MIN_CAREGIVER_RATING u300) ;; 3.0 rating minimum

;; Data Variables
(define-data-var next-pet-id uint u1)
(define-data-var next-caregiver-id uint u1)
(define-data-var next-booking-id uint u1)
(define-data-var contract-paused bool false)
(define-data-var platform-fee-rate uint u250) ;; 2.5% in basis points

;; Data Maps

;; Pet Profiles
(define-map pets
  { pet-id: uint }
  {
    owner: principal,
    name: (string-ascii 50),
    breed: (string-ascii 30),
    age: uint,
    weight: uint,
    medical-conditions: (string-ascii 200),
    care-requirements: (string-ascii 300),
    emergency-contact: (string-ascii 100),
    vaccination-records: (string-ascii 500),
    is-active: bool,
    created-at: uint
  }
)

;; Caregiver Profiles
(define-map caregivers
  { caregiver-id: uint }
  {
    principal: principal,
    name: (string-ascii 50),
    bio: (string-ascii 300),
    qualifications: (string-ascii 500),
    services-offered: (string-ascii 400),
    hourly-rate: uint,
    availability-hours: (string-ascii 100),
    rating: uint, ;; multiplied by 100 (e.g., 450 = 4.5 stars)
    total-reviews: uint,
    background-verified: bool,
    is-active: bool,
    created-at: uint
  }
)

;; Service Bookings
(define-map bookings
  { booking-id: uint }
  {
    pet-id: uint,
    caregiver-id: uint,
    owner: principal,
    caregiver: principal,
    service-type: (string-ascii 50),
    start-time: uint,
    end-time: uint,
    total-cost: uint,
    status: (string-ascii 20), ;; pending, confirmed, in-progress, completed, cancelled
    special-instructions: (string-ascii 500),
    payment-held: bool,
    created-at: uint
  }
)

;; Care Session Updates
(define-map session-updates
  { booking-id: uint, update-id: uint }
  {
    caregiver: principal,
    timestamp: uint,
    message: (string-ascii 300),
    pet-status: (string-ascii 100)
  }
)

;; Reviews and Ratings
(define-map reviews
  { booking-id: uint }
  {
    reviewer: principal,
    caregiver-id: uint,
    rating: uint, ;; 1-5 stars multiplied by 100
    comments: (string-ascii 500),
    service-quality: uint,
    communication: uint,
    reliability: uint,
    created-at: uint
  }
)

;; Pet Health Records
(define-map health-records
  { pet-id: uint, record-id: uint }
  {
    caregiver: principal,
    record-type: (string-ascii 30), ;; feeding, medication, exercise, health-check
    description: (string-ascii 400),
    timestamp: uint,
    additional-notes: (string-ascii 200)
  }
)

;; Owner and Caregiver Lookup Maps
(define-map owner-pets { owner: principal } { pet-ids: (list 20 uint) })
(define-map caregiver-lookup { principal: principal } { caregiver-id: uint })
(define-map pet-owner-lookup { pet-id: uint } { owner: principal })

;; Public Functions

;; Register a new pet profile
(define-public (register-pet 
    (name (string-ascii 50))
    (breed (string-ascii 30))
    (age uint)
    (weight uint)
    (medical-conditions (string-ascii 200))
    (care-requirements (string-ascii 300))
    (emergency-contact (string-ascii 100))
    (vaccination-records (string-ascii 500)))
  (let 
    (
      (pet-id (var-get next-pet-id))
      (current-pets (default-to { pet-ids: (list) } (map-get? owner-pets { owner: tx-sender })))
    )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_PARAMS)
    (asserts! (> age u0) ERR_INVALID_PARAMS)
    
    ;; Create pet profile
    (map-set pets 
      { pet-id: pet-id }
      {
        owner: tx-sender,
        name: name,
        breed: breed,
        age: age,
        weight: weight,
        medical-conditions: medical-conditions,
        care-requirements: care-requirements,
        emergency-contact: emergency-contact,
        vaccination-records: vaccination-records,
        is-active: true,
        created-at: stacks-block-height
      }
    )
    
    ;; Update owner pet lookup
    (map-set owner-pets 
      { owner: tx-sender }
      { pet-ids: (unwrap! (as-max-len? (append (get pet-ids current-pets) pet-id) u20) ERR_INVALID_PARAMS) }
    )
    
    ;; Update pet owner lookup
    (map-set pet-owner-lookup { pet-id: pet-id } { owner: tx-sender })
    
    ;; Increment next pet ID
    (var-set next-pet-id (+ pet-id u1))
    (ok pet-id)
  )
)

;; Register as a caregiver
(define-public (register-caregiver
    (name (string-ascii 50))
    (bio (string-ascii 300))
    (qualifications (string-ascii 500))
    (services-offered (string-ascii 400))
    (hourly-rate uint)
    (availability-hours (string-ascii 100)))
  (let 
    (
      (caregiver-id (var-get next-caregiver-id))
    )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_PARAMS)
    (asserts! (> hourly-rate u0) ERR_INVALID_PARAMS)
    (asserts! (is-none (map-get? caregiver-lookup { principal: tx-sender })) ERR_ALREADY_EXISTS)
    
    ;; Create caregiver profile
    (map-set caregivers
      { caregiver-id: caregiver-id }
      {
        principal: tx-sender,
        name: name,
        bio: bio,
        qualifications: qualifications,
        services-offered: services-offered,
        hourly-rate: hourly-rate,
        availability-hours: availability-hours,
        rating: u400, ;; Starting rating of 4.0
        total-reviews: u0,
        background-verified: false,
        is-active: true,
        created-at: stacks-block-height
      }
    )
    
    ;; Update caregiver lookup
    (map-set caregiver-lookup { principal: tx-sender } { caregiver-id: caregiver-id })
    
    ;; Increment next caregiver ID
    (var-set next-caregiver-id (+ caregiver-id u1))
    (ok caregiver-id)
  )
)

;; Book a care service
(define-public (book-service
    (pet-id uint)
    (caregiver-id uint)
    (service-type (string-ascii 50))
    (start-time uint)
    (end-time uint)
    (special-instructions (string-ascii 500)))
  (let 
    (
      (booking-id (var-get next-booking-id))
      (pet-info (unwrap! (map-get? pets { pet-id: pet-id }) ERR_NOT_FOUND))
      (caregiver-info (unwrap! (map-get? caregivers { caregiver-id: caregiver-id }) ERR_NOT_FOUND))
      (duration (- end-time start-time))
      (total-cost (* (get hourly-rate caregiver-info) duration))
    )
    (asserts! (not (var-get contract-paused)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get owner pet-info) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (get is-active pet-info) ERR_INVALID_PARAMS)
    (asserts! (get is-active caregiver-info) ERR_INVALID_PARAMS)
    (asserts! (> end-time start-time) ERR_INVALID_PARAMS)
    (asserts! (>= (get rating caregiver-info) MIN_CAREGIVER_RATING) ERR_INSUFFICIENT_RATING)
    
    ;; Create booking
    (map-set bookings
      { booking-id: booking-id }
      {
        pet-id: pet-id,
        caregiver-id: caregiver-id,
        owner: tx-sender,
        caregiver: (get principal caregiver-info),
        service-type: service-type,
        start-time: start-time,
        end-time: end-time,
        total-cost: total-cost,
        status: "pending",
        special-instructions: special-instructions,
        payment-held: false,
        created-at: stacks-block-height
      }
    )
    
    ;; Increment next booking ID
    (var-set next-booking-id (+ booking-id u1))
    (ok booking-id)
  )
)

;; Confirm booking (caregiver accepts)
(define-public (confirm-booking (booking-id uint))
  (let 
    (
      (booking-info (unwrap! (map-get? bookings { booking-id: booking-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq (get caregiver booking-info) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status booking-info) "pending") ERR_INVALID_PARAMS)
    
    ;; Update booking status
    (map-set bookings
      { booking-id: booking-id }
      (merge booking-info { status: "confirmed" })
    )
    (ok true)
  )
)

;; Add care session update
(define-public (add-session-update
    (booking-id uint)
    (update-id uint)
    (message (string-ascii 300))
    (pet-status (string-ascii 100)))
  (let 
    (
      (booking-info (unwrap! (map-get? bookings { booking-id: booking-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq (get caregiver booking-info) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (or (is-eq (get status booking-info) "confirmed") (is-eq (get status booking-info) "in-progress")) ERR_INVALID_PARAMS)
    
    ;; Add session update
    (map-set session-updates
      { booking-id: booking-id, update-id: update-id }
      {
        caregiver: tx-sender,
        timestamp: stacks-block-height,
        message: message,
        pet-status: pet-status
      }
    )
    (ok true)
  )
)

;; Complete service and submit review
(define-public (submit-review
    (booking-id uint)
    (rating uint)
    (comments (string-ascii 500))
    (service-quality uint)
    (communication uint)
    (reliability uint))
  (let 
    (
      (booking-info (unwrap! (map-get? bookings { booking-id: booking-id }) ERR_NOT_FOUND))
      (caregiver-info (unwrap! (map-get? caregivers { caregiver-id: (get caregiver-id booking-info) }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq (get owner booking-info) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status booking-info) "completed") ERR_INVALID_PARAMS)
    (asserts! (<= rating u500) ERR_INVALID_PARAMS) ;; Max 5.0 rating
    (asserts! (>= rating u100) ERR_INVALID_PARAMS) ;; Min 1.0 rating
    
    ;; Add review
    (map-set reviews
      { booking-id: booking-id }
      {
        reviewer: tx-sender,
        caregiver-id: (get caregiver-id booking-info),
        rating: rating,
        comments: comments,
        service-quality: service-quality,
        communication: communication,
        reliability: reliability,
        created-at: stacks-block-height
      }
    )
    
    ;; Update caregiver rating
    (let 
      (
        (total-reviews (+ (get total-reviews caregiver-info) u1))
        (current-rating (get rating caregiver-info))
        (new-rating (/ (+ (* current-rating (get total-reviews caregiver-info)) rating) total-reviews))
      )
      (map-set caregivers
        { caregiver-id: (get caregiver-id booking-info) }
        (merge caregiver-info { 
          rating: new-rating,
          total-reviews: total-reviews
        })
      )
    )
    (ok true)
  )
)

;; Add health record
(define-public (add-health-record
    (pet-id uint)
    (record-id uint)
    (record-type (string-ascii 30))
    (description (string-ascii 400))
    (additional-notes (string-ascii 200)))
  (let 
    (
      (pet-owner (unwrap! (map-get? pet-owner-lookup { pet-id: pet-id }) ERR_NOT_FOUND))
    )
    ;; Only pet owner or active caregiver can add health records
    (asserts! (or (is-eq (get owner pet-owner) tx-sender) 
                  (is-some (map-get? caregiver-lookup { principal: tx-sender }))) ERR_UNAUTHORIZED)
    
    (map-set health-records
      { pet-id: pet-id, record-id: record-id }
      {
        caregiver: tx-sender,
        record-type: record-type,
        description: description,
        timestamp: stacks-block-height,
        additional-notes: additional-notes
      }
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get pet profile
(define-read-only (get-pet (pet-id uint))
  (map-get? pets { pet-id: pet-id })
)

;; Get caregiver profile
(define-read-only (get-caregiver (caregiver-id uint))
  (map-get? caregivers { caregiver-id: caregiver-id })
)

;; Get booking details
(define-read-only (get-booking (booking-id uint))
  (map-get? bookings { booking-id: booking-id })
)

;; Get session updates
(define-read-only (get-session-update (booking-id uint) (update-id uint))
  (map-get? session-updates { booking-id: booking-id, update-id: update-id })
)

;; Get review
(define-read-only (get-review (booking-id uint))
  (map-get? reviews { booking-id: booking-id })
)

;; Get health record
(define-read-only (get-health-record (pet-id uint) (record-id uint))
  (map-get? health-records { pet-id: pet-id, record-id: record-id })
)

;; Get owner's pets
(define-read-only (get-owner-pets (owner principal))
  (map-get? owner-pets { owner: owner })
)

;; Get caregiver ID from principal
(define-read-only (get-caregiver-id (principal principal))
  (map-get? caregiver-lookup { principal: principal })
)

;; Get current pet ID counter
(define-read-only (get-next-pet-id)
  (var-get next-pet-id)
)

;; Get current caregiver ID counter
(define-read-only (get-next-caregiver-id)
  (var-get next-caregiver-id)
)

;; Get current booking ID counter
(define-read-only (get-next-booking-id)
  (var-get next-booking-id)
)

;; Get platform fee rate
(define-read-only (get-platform-fee-rate)
  (var-get platform-fee-rate)
)

;; Check if contract is paused
(define-read-only (is-contract-paused)
  (var-get contract-paused)
)

