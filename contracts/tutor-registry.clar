;; Tutor Registry Contract - Manages tutor verification and reputation system
;; This contract handles tutor applications, verification process, and reputation tracking

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-unauthorized (err u202))
(define-constant err-already-exists (err u203))
(define-constant err-invalid-application (err u204))
(define-constant err-already-verified (err u205))
(define-constant err-invalid-parameters (err u206))
(define-constant err-application-not-pending (err u207))
(define-constant err-insufficient-stake (err u208))

;; Application Status Constants
(define-constant application-pending u1)
(define-constant application-approved u2)
(define-constant application-rejected u3)
(define-constant application-under-review u4)

;; Verification Levels
(define-constant verification-basic u1)
(define-constant verification-premium u2)
(define-constant verification-expert u3)

;; Data Variables
(define-data-var next-application-id uint u1)
(define-data-var verification-fee uint u100000) ;; Fee in microSTX for verification
(define-data-var min-stake-amount uint u500000) ;; Minimum stake for premium verification
(define-data-var review-period uint u1440) ;; Review period in blocks (~10 days)

;; Tutor Applications
(define-map tutor-applications
  { application-id: uint }
  {
    applicant: principal,
    full-name: (string-ascii 100),
    email: (string-ascii 100),
    bio: (string-ascii 1000),
    qualifications: (list 10 (string-ascii 200)),
    subjects: (list 10 uint),
    hourly-rates: (list 10 uint),
    portfolio-url: (optional (string-ascii 200)),
    linkedin-url: (optional (string-ascii 200)),
    verification-level-requested: uint,
    stake-amount: uint,
    status: uint,
    applied-at: uint,
    reviewed-at: (optional uint),
    reviewer: (optional principal),
    rejection-reason: (optional (string-ascii 500))
  }
)

;; Verified Tutors Registry
(define-map verified-tutors
  { tutor: principal }
  {
    application-id: uint,
    verification-level: uint,
    verified-at: uint,
    verified-by: principal,
    full-name: (string-ascii 100),
    bio: (string-ascii 1000),
    subjects: (list 10 uint),
    qualifications: (list 10 (string-ascii 200)),
    hourly-rates: (list 10 uint),
    portfolio-url: (optional (string-ascii 200)),
    linkedin-url: (optional (string-ascii 200)),
    is-active: bool,
    reputation-score: uint,
    total-reviews: uint,
    average-rating: uint,
    stake-locked: uint
  }
)

;; Tutor Reviews and Ratings
(define-map tutor-reviews
  { review-id: uint }
  {
    tutor: principal,
    reviewer: principal,
    session-id: uint,
    rating: uint,
    review-text: (string-ascii 1000),
    review-date: uint,
    verified-purchase: bool
  }
)

;; Application lookup by tutor
(define-map tutor-to-application
  { tutor: principal }
  { application-id: uint }
)

;; Authorized Reviewers
(define-map authorized-reviewers
  { reviewer: principal }
  {
    is-authorized: bool,
    reviews-completed: uint,
    added-at: uint,
    added-by: principal
  }
)

;; Tutor Stakes (for premium verification)
(define-map tutor-stakes
  { tutor: principal }
  {
    amount-staked: uint,
    staked-at: uint,
    can-withdraw-after: uint
  }
)

;; Read-only Functions

;; Get tutor application
(define-read-only (get-application (application-id uint))
  (map-get? tutor-applications { application-id: application-id })
)

;; Get verified tutor info
(define-read-only (get-verified-tutor (tutor principal))
  (map-get? verified-tutors { tutor: tutor })
)

;; Check if tutor is verified
(define-read-only (is-tutor-verified (tutor principal))
  (is-some (get-verified-tutor tutor))
)

;; Get tutor verification level
(define-read-only (get-tutor-verification-level (tutor principal))
  (match (get-verified-tutor tutor)
    tutor-info (some (get verification-level tutor-info))
    none
  )
)

;; Get tutor application by tutor address
(define-read-only (get-tutor-application (tutor principal))
  (match (map-get? tutor-to-application { tutor: tutor })
    lookup (get-application (get application-id lookup))
    none
  )
)

;; Get verification fee
(define-read-only (get-verification-fee)
  (var-get verification-fee)
)

;; Get minimum stake amount
(define-read-only (get-min-stake-amount)
  (var-get min-stake-amount)
)

;; Check if principal is authorized reviewer
(define-read-only (is-authorized-reviewer (reviewer principal))
  (match (map-get? authorized-reviewers { reviewer: reviewer })
    reviewer-info (get is-authorized reviewer-info)
    false
  )
)

;; Get current application ID
(define-read-only (get-current-application-id)
  (var-get next-application-id)
)

;; Get tutor stake info
(define-read-only (get-tutor-stake (tutor principal))
  (map-get? tutor-stakes { tutor: tutor })
)

;; Private Functions

;; Validate application parameters
(define-private (validate-application-params 
    (full-name (string-ascii 100))
    (email (string-ascii 100))
    (subjects (list 10 uint))
    (hourly-rates (list 10 uint))
    (verification-level uint)
  )
  (and
    (> (len full-name) u0)
    (> (len email) u5) ;; Basic email validation
    (> (len subjects) u0)
    (> (len hourly-rates) u0)
    (and (>= verification-level verification-basic) 
         (<= verification-level verification-expert))
    (is-eq (len subjects) (len hourly-rates)) ;; Must have rates for all subjects
  )
)

;; Custom min function
(define-private (min-uint (a uint) (b uint))
  (if (<= a b) a b)
)

;; Calculate reputation score based on ratings
(define-private (calculate-reputation-score (average-rating uint) (total-reviews uint))
  (if (> total-reviews u0)
    (+ (* average-rating u20) (min-uint total-reviews u100)) ;; Score from 20-500 based on rating and volume
    u0
  )
)

;; Public Functions

;; Submit tutor application
(define-public (submit-application
    (full-name (string-ascii 100))
    (email (string-ascii 100))
    (bio (string-ascii 1000))
    (qualifications (list 10 (string-ascii 200)))
    (subjects (list 10 uint))
    (hourly-rates (list 10 uint))
    (portfolio-url (optional (string-ascii 200)))
    (linkedin-url (optional (string-ascii 200)))
    (verification-level uint)
  )
  (let (
    (application-id (var-get next-application-id))
    (applicant tx-sender)
    (required-stake (if (> verification-level verification-basic) 
                       (var-get min-stake-amount) 
                       u0))
  )
    ;; Validations
    (asserts! (validate-application-params full-name email subjects hourly-rates verification-level) 
              err-invalid-parameters)
    (asserts! (is-none (get-tutor-application applicant)) err-already-exists)
    
    ;; Check stake requirement for premium verifications
    (if (> required-stake u0)
      (asserts! (>= (stx-get-balance applicant) required-stake) err-insufficient-stake)
      true
    )
    
    ;; Create application
    (map-set tutor-applications
      { application-id: application-id }
      {
        applicant: applicant,
        full-name: full-name,
        email: email,
        bio: bio,
        qualifications: qualifications,
        subjects: subjects,
        hourly-rates: hourly-rates,
        portfolio-url: portfolio-url,
        linkedin-url: linkedin-url,
        verification-level-requested: verification-level,
        stake-amount: required-stake,
        status: application-pending,
        applied-at: burn-block-height,
        reviewed-at: none,
        reviewer: none,
        rejection-reason: none
      }
    )
    
    ;; Create lookup mapping
    (map-set tutor-to-application
      { tutor: applicant }
      { application-id: application-id }
    )
    
    ;; Lock stake if required
    (if (> required-stake u0)
      (begin
        (try! (stx-transfer? required-stake applicant (as-contract tx-sender)))
        (map-set tutor-stakes
          { tutor: applicant }
          {
            amount-staked: required-stake,
            staked-at: burn-block-height,
            can-withdraw-after: (+ burn-block-height (var-get review-period))
          }
        )
      )
      true
    )
    
    ;; Increment application ID
    (var-set next-application-id (+ application-id u1))
    
    (ok application-id)
  )
)

;; Review and approve tutor application (authorized reviewers only)
(define-public (approve-application (application-id uint))
  (let (
    (application (unwrap! (get-application application-id) err-not-found))
    (applicant (get applicant application))
  )
    ;; Validations
    (asserts! (or (is-eq tx-sender contract-owner) 
                  (is-authorized-reviewer tx-sender)) err-unauthorized)
    (asserts! (is-eq (get status application) application-pending) err-application-not-pending)
    
    ;; Update application status
    (map-set tutor-applications
      { application-id: application-id }
      (merge application {
        status: application-approved,
        reviewed-at: (some burn-block-height),
        reviewer: (some tx-sender)
      })
    )
    
    ;; Add to verified tutors registry
    (map-set verified-tutors
      { tutor: applicant }
      {
        application-id: application-id,
        verification-level: (get verification-level-requested application),
        verified-at: burn-block-height,
        verified-by: tx-sender,
        full-name: (get full-name application),
        bio: (get bio application),
        subjects: (get subjects application),
        qualifications: (get qualifications application),
        hourly-rates: (get hourly-rates application),
        portfolio-url: (get portfolio-url application),
        linkedin-url: (get linkedin-url application),
        is-active: true,
        reputation-score: u0,
        total-reviews: u0,
        average-rating: u0,
        stake-locked: (get stake-amount application)
      }
    )
    
    ;; Update reviewer stats
    (match (map-get? authorized-reviewers { reviewer: tx-sender })
      reviewer-info
        (map-set authorized-reviewers
          { reviewer: tx-sender }
          (merge reviewer-info {
            reviews-completed: (+ (get reviews-completed reviewer-info) u1)
          })
        )
      true ;; If owner is reviewing, no need to update reviewer stats
    )
    
    (ok true)
  )
)

;; Reject tutor application (authorized reviewers only)
(define-public (reject-application (application-id uint) (reason (string-ascii 500)))
  (let (
    (application (unwrap! (get-application application-id) err-not-found))
    (applicant (get applicant application))
    (stake-amount (get stake-amount application))
  )
    ;; Validations
    (asserts! (or (is-eq tx-sender contract-owner) 
                  (is-authorized-reviewer tx-sender)) err-unauthorized)
    (asserts! (is-eq (get status application) application-pending) err-application-not-pending)
    
    ;; Update application status
    (map-set tutor-applications
      { application-id: application-id }
      (merge application {
        status: application-rejected,
        reviewed-at: (some burn-block-height),
        reviewer: (some tx-sender),
        rejection-reason: (some reason)
      })
    )
    
    ;; Refund stake if applicable
    (if (> stake-amount u0)
      (begin
        (try! (as-contract (stx-transfer? stake-amount tx-sender applicant)))
        (map-delete tutor-stakes { tutor: applicant })
      )
      true
    )
    
    ;; Update reviewer stats
    (match (map-get? authorized-reviewers { reviewer: tx-sender })
      reviewer-info
        (map-set authorized-reviewers
          { reviewer: tx-sender }
          (merge reviewer-info {
            reviews-completed: (+ (get reviews-completed reviewer-info) u1)
          })
        )
      true
    )
    
    (ok true)
  )
)

;; Deactivate tutor (admin or tutor themselves)
(define-public (deactivate-tutor (tutor principal))
  (let (
    (tutor-info (unwrap! (get-verified-tutor tutor) err-not-found))
  )
    (asserts! (or (is-eq tx-sender contract-owner)
                  (is-eq tx-sender tutor)) err-unauthorized)
    
    (map-set verified-tutors
      { tutor: tutor }
      (merge tutor-info { is-active: false })
    )
    
    (ok true)
  )
)

;; Reactivate tutor (tutor themselves only)
(define-public (reactivate-tutor)
  (let (
    (tutor tx-sender)
    (tutor-info (unwrap! (get-verified-tutor tutor) err-not-found))
  )
    (map-set verified-tutors
      { tutor: tutor }
      (merge tutor-info { is-active: true })
    )
    
    (ok true)
  )
)

;; Update tutor profile (verified tutors only)
(define-public (update-tutor-profile 
    (bio (string-ascii 1000))
    (hourly-rates (list 10 uint))
    (portfolio-url (optional (string-ascii 200)))
  )
  (let (
    (tutor tx-sender)
    (tutor-info (unwrap! (get-verified-tutor tutor) err-not-found))
  )
    (asserts! (get is-active tutor-info) err-unauthorized)
    
    (map-set verified-tutors
      { tutor: tutor }
      (merge tutor-info {
        bio: bio,
        hourly-rates: hourly-rates,
        portfolio-url: portfolio-url
      })
    )
    
    (ok true)
  )
)

;; Withdraw stake (after review period)
(define-public (withdraw-stake)
  (let (
    (tutor tx-sender)
    (stake-info (unwrap! (get-tutor-stake tutor) err-not-found))
    (amount (get amount-staked stake-info))
  )
    (asserts! (>= burn-block-height (get can-withdraw-after stake-info)) err-unauthorized)
    
    (try! (as-contract (stx-transfer? amount tx-sender tutor)))
    (map-delete tutor-stakes { tutor: tutor })
    
    (ok amount)
  )
)

;; Administrative Functions

;; Add authorized reviewer (owner only)
(define-public (add-authorized-reviewer (reviewer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set authorized-reviewers
      { reviewer: reviewer }
      {
        is-authorized: true,
        reviews-completed: u0,
        added-at: burn-block-height,
        added-by: contract-owner
      }
    )
    (ok true)
  )
)

;; Remove authorized reviewer (owner only)
(define-public (remove-authorized-reviewer (reviewer principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (match (map-get? authorized-reviewers { reviewer: reviewer })
      reviewer-info
        (map-set authorized-reviewers
          { reviewer: reviewer }
          (merge reviewer-info { is-authorized: false })
        )
      false
    )
    (ok true)
  )
)

;; Set verification fee (owner only)
(define-public (set-verification-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set verification-fee new-fee)
    (ok true)
  )
)

;; Set minimum stake amount (owner only)
(define-public (set-min-stake-amount (new-amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-stake-amount new-amount)
    (ok true)
  )
)

