;; Title: Emergency Response Contract
;; Version: 1.0.0
;; Summary: Coordinates pet emergency response networks with 24/7 veterinary access
;; Description: Manages urgent care protocols, pet identification, insurance integration, and real-time health monitoring

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_ALREADY_EXISTS (err u202))
(define-constant ERR_INVALID_PARAMS (err u203))
(define-constant ERR_EMERGENCY_ACTIVE (err u204))
(define-constant ERR_INSURANCE_DENIED (err u205))
(define-constant ERR_VET_UNAVAILABLE (err u206))
(define-constant EMERGENCY_PRIORITY_HIGH u3)
(define-constant EMERGENCY_PRIORITY_MEDIUM u2)
(define-constant EMERGENCY_PRIORITY_LOW u1)
(define-constant MAX_RESPONSE_TIME u30) ;; 30 blocks maximum response time

;; Data Variables
(define-data-var next-emergency-id uint u1)
(define-data-var next-vet-id uint u1)
(define-data-var next-claim-id uint u1)
(define-data-var emergency-response-active bool true)
(define-data-var base-emergency-fee uint u1000000) ;; 1 STX base fee

;; Data Maps

;; Emergency Cases
(define-map emergencies
  { emergency-id: uint }
  {
    pet-id: uint,
    owner: principal,
    emergency-type: (string-ascii 50), ;; injury, illness, lost, behavioral, poisoning
    priority-level: uint,
    description: (string-ascii 500),
    location: (string-ascii 200),
    contact-info: (string-ascii 150),
    status: (string-ascii 20), ;; active, assigned, in-progress, resolved, closed
    assigned-vet: (optional principal),
    created-at: uint,
    response-time: (optional uint),
    resolution-time: (optional uint)
  }
)

;; Veterinary Providers
(define-map emergency-vets
  { vet-id: uint }
  {
    principal: principal,
    name: (string-ascii 50),
    clinic-name: (string-ascii 100),
    specialties: (string-ascii 300),
    location: (string-ascii 200),
    availability-24h: bool,
    emergency-certified: bool,
    rating: uint, ;; multiplied by 100
    total-cases: uint,
    response-time-avg: uint,
    contact-phone: (string-ascii 20),
    contact-email: (string-ascii 100),
    is-active: bool,
    created-at: uint
  }
)

;; Pet Emergency Profiles
(define-map pet-emergency-profiles
  { pet-id: uint }
  {
    owner: principal,
    emergency-contacts: (string-ascii 300),
    medical-alerts: (string-ascii 400),
    medications: (string-ascii 300),
    allergies: (string-ascii 200),
    insurance-policy: (optional uint),
    preferred-vet: (optional uint),
    microchip-id: (string-ascii 50),
    last-updated: uint
  }
)

;; Emergency Response Actions
(define-map response-actions
  { emergency-id: uint, action-id: uint }
  {
    vet: principal,
    action-type: (string-ascii 30), ;; assessment, treatment, transport, medication
    description: (string-ascii 400),
    timestamp: uint,
    cost: uint,
    urgent: bool
  }
)

;; Insurance Claims
(define-map insurance-claims
  { claim-id: uint }
  {
    policy-holder: principal,
    pet-id: uint,
    emergency-id: uint,
    claim-amount: uint,
    description: (string-ascii 500),
    status: (string-ascii 20), ;; submitted, reviewing, approved, denied, paid
    submitted-at: uint,
    processed-at: (optional uint),
    payout-amount: (optional uint)
  }
)

;; Real-time Health Monitoring
(define-map health-monitoring
  { pet-id: uint, monitoring-id: uint }
  {
    reporter: principal, ;; owner, vet, or caregiver
    vital-signs: (string-ascii 200),
    behavior-notes: (string-ascii 300),
    alert-level: uint, ;; 1-5 scale
    requires-attention: bool,
    timestamp: uint,
    follow-up-required: bool
  }
)

;; Vet Availability Schedule
(define-map vet-availability
  { vet-id: uint }
  {
    current-capacity: uint,
    max-capacity: uint,
    on-call-hours: (string-ascii 100),
    emergency-only: bool,
    last-updated: uint
  }
)

;; Emergency Response Network
(define-map response-network
  { location-zone: (string-ascii 50) }
  {
    available-vets: (list 10 uint),
    response-coordinators: (list 5 principal),
    average-response-time: uint,
    total-emergencies: uint
  }
)

;; Public Functions

;; Register emergency veterinary provider
(define-public (register-emergency-vet
    (name (string-ascii 50))
    (clinic-name (string-ascii 100))
    (specialties (string-ascii 300))
    (location (string-ascii 200))
    (availability-24h bool)
    (contact-phone (string-ascii 20))
    (contact-email (string-ascii 100)))
  (let 
    (
      (vet-id (var-get next-vet-id))
    )
    (asserts! (var-get emergency-response-active) ERR_UNAUTHORIZED)
    (asserts! (> (len name) u0) ERR_INVALID_PARAMS)
    (asserts! (> (len clinic-name) u0) ERR_INVALID_PARAMS)
    
    ;; Create vet profile
    (map-set emergency-vets
      { vet-id: vet-id }
      {
        principal: tx-sender,
        name: name,
        clinic-name: clinic-name,
        specialties: specialties,
        location: location,
        availability-24h: availability-24h,
        emergency-certified: false, ;; Needs verification
        rating: u400, ;; Starting rating 4.0
        total-cases: u0,
        response-time-avg: u15, ;; 15 blocks average
        contact-phone: contact-phone,
        contact-email: contact-email,
        is-active: true,
        created-at: stacks-block-height
      }
    )
    
    ;; Initialize availability
    (map-set vet-availability
      { vet-id: vet-id }
      {
        current-capacity: u0,
        max-capacity: u5,
        on-call-hours: "24/7",
        emergency-only: availability-24h,
        last-updated: stacks-block-height
      }
    )
    
    ;; Increment next vet ID
    (var-set next-vet-id (+ vet-id u1))
    (ok vet-id)
  )
)

;; Create pet emergency profile
(define-public (create-emergency-profile
    (pet-id uint)
    (emergency-contacts (string-ascii 300))
    (medical-alerts (string-ascii 400))
    (medications (string-ascii 300))
    (allergies (string-ascii 200))
    (microchip-id (string-ascii 50)))
  (begin
    (asserts! (var-get emergency-response-active) ERR_UNAUTHORIZED)
    (asserts! (> pet-id u0) ERR_INVALID_PARAMS)
    
    (map-set pet-emergency-profiles
      { pet-id: pet-id }
      {
        owner: tx-sender,
        emergency-contacts: emergency-contacts,
        medical-alerts: medical-alerts,
        medications: medications,
        allergies: allergies,
        insurance-policy: none,
        preferred-vet: none,
        microchip-id: microchip-id,
        last-updated: stacks-block-height
      }
    )
    (ok pet-id)
  )
)

;; Report emergency
(define-public (report-emergency
    (pet-id uint)
    (emergency-type (string-ascii 50))
    (priority-level uint)
    (description (string-ascii 500))
    (location (string-ascii 200))
    (contact-info (string-ascii 150)))
  (let 
    (
      (emergency-id (var-get next-emergency-id))
      (emergency-fee (var-get base-emergency-fee))
    )
    (asserts! (var-get emergency-response-active) ERR_UNAUTHORIZED)
    (asserts! (> pet-id u0) ERR_INVALID_PARAMS)
    (asserts! (<= priority-level EMERGENCY_PRIORITY_HIGH) ERR_INVALID_PARAMS)
    (asserts! (>= priority-level EMERGENCY_PRIORITY_LOW) ERR_INVALID_PARAMS)
    (asserts! (> (len description) u10) ERR_INVALID_PARAMS)
    
    ;; Create emergency case
    (map-set emergencies
      { emergency-id: emergency-id }
      {
        pet-id: pet-id,
        owner: tx-sender,
        emergency-type: emergency-type,
        priority-level: priority-level,
        description: description,
        location: location,
        contact-info: contact-info,
        status: "active",
        assigned-vet: none,
        created-at: stacks-block-height,
        response-time: none,
        resolution-time: none
      }
    )
    
    ;; Increment next emergency ID
    (var-set next-emergency-id (+ emergency-id u1))
    (ok emergency-id)
  )
)

;; Assign veterinarian to emergency
(define-public (assign-vet-to-emergency (emergency-id uint) (vet-id uint))
  (let 
    (
      (emergency-info (unwrap! (map-get? emergencies { emergency-id: emergency-id }) ERR_NOT_FOUND))
      (vet-info (unwrap! (map-get? emergency-vets { vet-id: vet-id }) ERR_NOT_FOUND))
      (vet-availability-info (unwrap! (map-get? vet-availability { vet-id: vet-id }) ERR_NOT_FOUND))
    )
    (asserts! (or (is-eq (get owner emergency-info) tx-sender) 
                  (is-eq (get principal vet-info) tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status emergency-info) "active") ERR_INVALID_PARAMS)
    (asserts! (get is-active vet-info) ERR_VET_UNAVAILABLE)
    (asserts! (< (get current-capacity vet-availability-info) (get max-capacity vet-availability-info)) ERR_VET_UNAVAILABLE)
    
    ;; Update emergency with assigned vet
    (map-set emergencies
      { emergency-id: emergency-id }
      (merge emergency-info {
        status: "assigned",
        assigned-vet: (some (get principal vet-info)),
        response-time: (some (- stacks-block-height (get created-at emergency-info)))
      })
    )
    
    ;; Update vet capacity
    (map-set vet-availability
      { vet-id: vet-id }
      (merge vet-availability-info {
        current-capacity: (+ (get current-capacity vet-availability-info) u1),
        last-updated: stacks-block-height
      })
    )
    
    (ok true)
  )
)

;; Add response action
(define-public (add-response-action
    (emergency-id uint)
    (action-id uint)
    (action-type (string-ascii 30))
    (description (string-ascii 400))
    (cost uint)
    (urgent bool))
  (let 
    (
      (emergency-info (unwrap! (map-get? emergencies { emergency-id: emergency-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-some (get assigned-vet emergency-info)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (unwrap! (get assigned-vet emergency-info) ERR_UNAUTHORIZED) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (or (is-eq (get status emergency-info) "assigned") 
                  (is-eq (get status emergency-info) "in-progress")) ERR_INVALID_PARAMS)
    
    ;; Add response action
    (map-set response-actions
      { emergency-id: emergency-id, action-id: action-id }
      {
        vet: tx-sender,
        action-type: action-type,
        description: description,
        timestamp: stacks-block-height,
        cost: cost,
        urgent: urgent
      }
    )
    
    ;; Update emergency status if first action
    (if (is-eq (get status emergency-info) "assigned")
      (map-set emergencies
        { emergency-id: emergency-id }
        (merge emergency-info { status: "in-progress" })
      )
      true
    )
    
    (ok true)
  )
)

;; Submit insurance claim
(define-public (submit-insurance-claim
    (pet-id uint)
    (emergency-id uint)
    (claim-amount uint)
    (description (string-ascii 500)))
  (let 
    (
      (claim-id (var-get next-claim-id))
      (emergency-info (unwrap! (map-get? emergencies { emergency-id: emergency-id }) ERR_NOT_FOUND))
      (pet-profile (map-get? pet-emergency-profiles { pet-id: pet-id }))
    )
    (asserts! (is-eq (get owner emergency-info) tx-sender) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get pet-id emergency-info) pet-id) ERR_INVALID_PARAMS)
    (asserts! (> claim-amount u0) ERR_INVALID_PARAMS)
    
    ;; Create insurance claim
    (map-set insurance-claims
      { claim-id: claim-id }
      {
        policy-holder: tx-sender,
        pet-id: pet-id,
        emergency-id: emergency-id,
        claim-amount: claim-amount,
        description: description,
        status: "submitted",
        submitted-at: stacks-block-height,
        processed-at: none,
        payout-amount: none
      }
    )
    
    ;; Increment next claim ID
    (var-set next-claim-id (+ claim-id u1))
    (ok claim-id)
  )
)

;; Add health monitoring data
(define-public (add-health-monitoring
    (pet-id uint)
    (monitoring-id uint)
    (vital-signs (string-ascii 200))
    (behavior-notes (string-ascii 300))
    (alert-level uint)
    (requires-attention bool))
  (begin
    (asserts! (var-get emergency-response-active) ERR_UNAUTHORIZED)
    (asserts! (> pet-id u0) ERR_INVALID_PARAMS)
    (asserts! (<= alert-level u5) ERR_INVALID_PARAMS)
    (asserts! (>= alert-level u1) ERR_INVALID_PARAMS)
    
    (map-set health-monitoring
      { pet-id: pet-id, monitoring-id: monitoring-id }
      {
        reporter: tx-sender,
        vital-signs: vital-signs,
        behavior-notes: behavior-notes,
        alert-level: alert-level,
        requires-attention: requires-attention,
        timestamp: stacks-block-height,
        follow-up-required: (>= alert-level u4)
      }
    )
    (ok true)
  )
)

;; Close emergency case
(define-public (close-emergency (emergency-id uint) (resolution-notes (string-ascii 400)))
  (let 
    (
      (emergency-info (unwrap! (map-get? emergencies { emergency-id: emergency-id }) ERR_NOT_FOUND))
    )
    (asserts! (or (is-eq (get owner emergency-info) tx-sender)
                  (is-eq (unwrap! (get assigned-vet emergency-info) ERR_UNAUTHORIZED) tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status emergency-info) "in-progress") ERR_INVALID_PARAMS)
    
    ;; Close emergency
    (map-set emergencies
      { emergency-id: emergency-id }
      (merge emergency-info {
        status: "resolved",
        resolution-time: (some (- stacks-block-height (get created-at emergency-info)))
      })
    )
    
    (ok true)
  )
)

;; Read-only Functions

;; Get emergency details
(define-read-only (get-emergency (emergency-id uint))
  (map-get? emergencies { emergency-id: emergency-id })
)

;; Get emergency vet profile
(define-read-only (get-emergency-vet (vet-id uint))
  (map-get? emergency-vets { vet-id: vet-id })
)

;; Get pet emergency profile
(define-read-only (get-pet-emergency-profile (pet-id uint))
  (map-get? pet-emergency-profiles { pet-id: pet-id })
)

;; Get response action
(define-read-only (get-response-action (emergency-id uint) (action-id uint))
  (map-get? response-actions { emergency-id: emergency-id, action-id: action-id })
)

;; Get insurance claim
(define-read-only (get-insurance-claim (claim-id uint))
  (map-get? insurance-claims { claim-id: claim-id })
)

;; Get health monitoring data
(define-read-only (get-health-monitoring (pet-id uint) (monitoring-id uint))
  (map-get? health-monitoring { pet-id: pet-id, monitoring-id: monitoring-id })
)

;; Get vet availability
(define-read-only (get-vet-availability (vet-id uint))
  (map-get? vet-availability { vet-id: vet-id })
)

;; Get response network info
(define-read-only (get-response-network (location-zone (string-ascii 50)))
  (map-get? response-network { location-zone: location-zone })
)

;; Get current emergency ID counter
(define-read-only (get-next-emergency-id)
  (var-get next-emergency-id)
)

;; Get current vet ID counter
(define-read-only (get-next-vet-id)
  (var-get next-vet-id)
)

;; Get current claim ID counter
(define-read-only (get-next-claim-id)
  (var-get next-claim-id)
)

;; Check if emergency response is active
(define-read-only (is-emergency-response-active)
  (var-get emergency-response-active)
)

;; Get base emergency fee
(define-read-only (get-base-emergency-fee)
  (var-get base-emergency-fee)
)

