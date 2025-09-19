;; Tutorbit Core Contract - Tokenized Tutoring Sessions with NFT Proof-of-Completion
;; This contract manages tutoring sessions and mints NFTs as proof of completion

;; NFT Definition
(define-non-fungible-token tutorbit-session-nft uint)

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-session (err u104))
(define-constant err-session-not-completed (err u105))
(define-constant err-already-completed (err u106))
(define-constant err-invalid-parameters (err u107))
(define-constant err-tutor-not-verified (err u108))

;; Data Variables
(define-data-var next-session-id uint u1)
(define-data-var platform-fee-basis-points uint u250) ;; 2.5% platform fee
(define-data-var min-session-duration uint u1800) ;; 30 minutes minimum
(define-data-var max-session-duration uint u14400) ;; 4 hours maximum

;; Session Status Types
(define-constant session-pending u1)
(define-constant session-active u2) 
(define-constant session-completed u3)
(define-constant session-cancelled u4)

;; Subject Categories
(define-constant subject-math u1)
(define-constant subject-science u2)
(define-constant subject-english u3)
(define-constant subject-history u4)
(define-constant subject-programming u5)
(define-constant subject-other u6)

;; Session Data Structure
(define-map sessions
  { session-id: uint }
  {
    tutor: principal,
    student: principal,
    subject: uint,
    topic: (string-ascii 100),
    duration: uint,
    price: uint,
    status: uint,
    created-at: uint,
    started-at: (optional uint),
    completed-at: (optional uint),
    session-hash: (buff 32),
    rating: (optional uint),
    review: (optional (string-ascii 500))
  }
)

;; Tutor Profiles
(define-map tutor-profiles
  { tutor: principal }
  {
    is-verified: bool,
    total-sessions: uint,
    avg-rating: uint,
    total-earnings: uint,
    subjects-taught: (list 10 uint),
    bio: (string-ascii 500)
  }
)

;; Student Profiles  
(define-map student-profiles
  { student: principal }
  {
    total-sessions: uint,
    total-spent: uint,
    certificates-earned: uint,
    favorite-subjects: (list 5 uint)
  }
)

;; Session Certificates (NFT Metadata)
(define-map session-certificates
  { token-id: uint }
  {
    session-id: uint,
    student: principal,
    tutor: principal,
    subject: uint,
    topic: (string-ascii 100),
    completion-date: uint,
    grade: (optional (string-ascii 2)),
    skills-learned: (list 5 (string-ascii 50)),
    certificate-hash: (buff 32)
  }
)

;; Session Payments
(define-map session-payments
  { session-id: uint }
  {
    total-amount: uint,
    platform-fee: uint,
    tutor-payout: uint,
    payment-status: uint,
    paid-at: (optional uint)
  }
)

;; Read-only Functions

;; Get session details
(define-read-only (get-session (session-id uint))
  (map-get? sessions { session-id: session-id })
)

;; Get tutor profile
(define-read-only (get-tutor-profile (tutor principal))
  (map-get? tutor-profiles { tutor: tutor })
)

;; Get student profile
(define-read-only (get-student-profile (student principal))
  (map-get? student-profiles { student: student })
)

;; Get session certificate
(define-read-only (get-session-certificate (token-id uint))
  (map-get? session-certificates { token-id: token-id })
)

;; Get session payment details
(define-read-only (get-session-payment (session-id uint))
  (map-get? session-payments { session-id: session-id })
)

;; Get current session ID
(define-read-only (get-current-session-id)
  (var-get next-session-id)
)

;; Get platform fee
(define-read-only (get-platform-fee)
  (var-get platform-fee-basis-points)
)

;; Check if tutor is verified
(define-read-only (is-tutor-verified (tutor principal))
  (match (get-tutor-profile tutor)
    profile (get is-verified profile)
    false
  )
)

;; Get NFT owner
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? tutorbit-session-nft token-id))
)

;; Get last token ID
(define-read-only (get-last-token-id)
  (ok (- (var-get next-session-id) u1))
)

;; Get token URI (placeholder)
(define-read-only (get-token-uri (token-id uint))
  (ok (some "https://api.tutorbit.io/metadata/"))
)

;; Private Functions

;; Calculate platform fee
(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee-basis-points)) u10000)
)

;; Calculate tutor payout
(define-private (calculate-tutor-payout (amount uint))
  (- amount (calculate-platform-fee amount))
)

;; Validate session parameters
(define-private (validate-session-params (duration uint) (price uint) (subject uint))
  (and 
    (>= duration (var-get min-session-duration))
    (<= duration (var-get max-session-duration))
    (> price u0)
    (<= subject subject-other)
    (>= subject subject-math)
  )
)

;; Public Functions

;; Register as tutor (simplified - normally would require verification)
(define-public (register-tutor (subjects (list 10 uint)) (bio (string-ascii 500)))
  (let (
    (caller tx-sender)
  )
    (asserts! (is-none (get-tutor-profile caller)) err-already-exists)
    (map-set tutor-profiles
      { tutor: caller }
      {
        is-verified: false, ;; Starts unverified
        total-sessions: u0,
        avg-rating: u0,
        total-earnings: u0,
        subjects-taught: subjects,
        bio: bio
      }
    )
    (ok caller)
  )
)

;; Verify tutor (admin only)
(define-public (verify-tutor (tutor principal))
  (let (
    (profile (unwrap! (get-tutor-profile tutor) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set tutor-profiles
      { tutor: tutor }
      (merge profile { is-verified: true })
    )
    (ok true)
  )
)

;; Create tutoring session
(define-public (create-session 
    (tutor principal)
    (subject uint)
    (topic (string-ascii 100))
    (duration uint)
    (price uint)
    (session-hash (buff 32))
  )
  (let (
    (session-id (var-get next-session-id))
    (student tx-sender)
  )
    ;; Validations
    (asserts! (not (is-eq student tutor)) err-invalid-parameters)
    (asserts! (validate-session-params duration price subject) err-invalid-parameters)
    (asserts! (is-tutor-verified tutor) err-tutor-not-verified)
    
    ;; Create session
    (map-set sessions
      { session-id: session-id }
      {
        tutor: tutor,
        student: student,
        subject: subject,
        topic: topic,
        duration: duration,
        price: price,
        status: session-pending,
        created-at: burn-block-height,
        started-at: none,
        completed-at: none,
        session-hash: session-hash,
        rating: none,
        review: none
      }
    )
    
    ;; Create payment record
    (map-set session-payments
      { session-id: session-id }
      {
        total-amount: price,
        platform-fee: (calculate-platform-fee price),
        tutor-payout: (calculate-tutor-payout price),
        payment-status: u1, ;; Pending
        paid-at: none
      }
    )
    
    ;; Initialize student profile if needed
    (if (is-none (get-student-profile student))
      (map-set student-profiles
        { student: student }
        {
          total-sessions: u0,
          total-spent: u0,
          certificates-earned: u0,
          favorite-subjects: (list)
        }
      )
      true
    )
    
    ;; Increment session ID
    (var-set next-session-id (+ session-id u1))
    
    (ok session-id)
  )
)

;; Start session (tutor only)
(define-public (start-session (session-id uint))
  (let (
    (session (unwrap! (get-session session-id) err-not-found))
  )
    (asserts! (is-eq tx-sender (get tutor session)) err-unauthorized)
    (asserts! (is-eq (get status session) session-pending) err-invalid-session)
    
    (map-set sessions
      { session-id: session-id }
      (merge session {
        status: session-active,
        started-at: (some burn-block-height)
      })
    )
    
    (ok true)
  )
)

;; Complete session and mint NFT certificate
(define-public (complete-session 
    (session-id uint)
    (grade (optional (string-ascii 2)))
    (skills-learned (list 5 (string-ascii 50)))
    (certificate-hash (buff 32))
  )
  (let (
    (session (unwrap! (get-session session-id) err-not-found))
    (tutor (get tutor session))
    (student (get student session))
    (token-id session-id) ;; Use session-id as token-id for simplicity
  )
    (asserts! (is-eq tx-sender tutor) err-unauthorized)
    (asserts! (is-eq (get status session) session-active) err-invalid-session)
    
    ;; Update session status
    (map-set sessions
      { session-id: session-id }
      (merge session {
        status: session-completed,
        completed-at: (some burn-block-height)
      })
    )
    
    ;; Mint NFT certificate to student
    (try! (nft-mint? tutorbit-session-nft token-id student))
    
    ;; Create certificate metadata
    (map-set session-certificates
      { token-id: token-id }
      {
        session-id: session-id,
        student: student,
        tutor: tutor,
        subject: (get subject session),
        topic: (get topic session),
        completion-date: burn-block-height,
        grade: grade,
        skills-learned: skills-learned,
        certificate-hash: certificate-hash
      }
    )
    
    ;; Update tutor stats
    (let (
      (tutor-profile (unwrap! (get-tutor-profile tutor) err-not-found))
      (new-session-count (+ (get total-sessions tutor-profile) u1))
      (new-earnings (+ (get total-earnings tutor-profile) (calculate-tutor-payout (get price session))))
    )
      (map-set tutor-profiles
        { tutor: tutor }
        (merge tutor-profile {
          total-sessions: new-session-count,
          total-earnings: new-earnings
        })
      )
    )
    
    ;; Update student stats
    (let (
      (student-profile (unwrap! (get-student-profile student) err-not-found))
      (new-session-count (+ (get total-sessions student-profile) u1))
      (new-total-spent (+ (get total-spent student-profile) (get price session)))
      (new-certificates (+ (get certificates-earned student-profile) u1))
    )
      (map-set student-profiles
        { student: student }
        (merge student-profile {
          total-sessions: new-session-count,
          total-spent: new-total-spent,
          certificates-earned: new-certificates
        })
      )
    )
    
    (ok token-id)
  )
)

;; Rate and review session (student only)
(define-public (rate-session (session-id uint) (rating uint) (review (string-ascii 500)))
  (let (
    (session (unwrap! (get-session session-id) err-not-found))
  )
    (asserts! (is-eq tx-sender (get student session)) err-unauthorized)
    (asserts! (is-eq (get status session) session-completed) err-session-not-completed)
    (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-parameters)
    (asserts! (is-none (get rating session)) err-already-completed)
    
    (map-set sessions
      { session-id: session-id }
      (merge session {
        rating: (some rating),
        review: (some review)
      })
    )
    
    (ok true)
  )
)

;; Transfer NFT
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-unauthorized)
    (nft-transfer? tutorbit-session-nft token-id sender recipient)
  )
)

;; Administrative Functions

;; Set platform fee (owner only)
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-parameters) ;; Max 10%
    (var-set platform-fee-basis-points new-fee)
    (ok true)
  )
)

;; Set session duration limits (owner only)
(define-public (set-session-duration-limits (min-duration uint) (max-duration uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (< min-duration max-duration) err-invalid-parameters)
    (var-set min-session-duration min-duration)
    (var-set max-session-duration max-duration)
    (ok true)
  )
)

;; title: tutorbit-core
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

