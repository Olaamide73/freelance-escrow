;; ============================================================
;; freelance-escrow.clar
;; A decentralized escrow for freelance jobs using STX payments
;; ============================================================

(define-constant ERR_NOT_CLIENT (err u100))
(define-constant ERR_NOT_FREELANCER (err u101))
(define-constant ERR_JOB_NOT_FOUND (err u102))
(define-constant ERR_JOB_ALREADY_TAKEN (err u103))
(define-constant ERR_JOB_NOT_COMPLETED (err u104))
(define-constant ERR_ALREADY_COMPLETED (err u105))
(define-constant ERR_INVALID_AMOUNT (err u106))
(define-constant ERR_NOT_AUTHORIZED (err u107))

;; ------------------------------
;; STRUCTURE
;; ------------------------------
(define-map jobs
  { id: uint }
  {
    client: principal,
    freelancer: (optional principal),
    description: (string-ascii 200),
    amount: uint,
    completed: bool,
    paid: bool
  }
)

(define-data-var job-counter uint u0)
(define-constant admin tx-sender)

;; ------------------------------
;; EVENTS
;; ------------------------------
(define-data-var job-posted-event { job-id: uint, client: principal, amount: uint } { job-id: u0, client: tx-sender, amount: u0 })
(define-data-var job-accepted-event { job-id: uint, freelancer: principal } { job-id: u0, freelancer: tx-sender })

(define-private (job-posted (job-id uint) (client principal) (amount uint))
  (begin
    (var-set job-posted-event { job-id: job-id, client: client, amount: amount })
    { job-id: job-id, client: client, amount: amount }
  ))

(define-private (job-accepted (job-id uint) (freelancer principal))
  (begin
    (var-set job-accepted-event { job-id: job-id, freelancer: freelancer })
    { job-id: job-id, freelancer: freelancer }
  ))

(define-data-var job-completed-event { job-id: uint } { job-id: u0 })
(define-data-var job-paid-event { job-id: uint, freelancer: principal, amount: uint } { job-id: u0, freelancer: tx-sender, amount: u0 })

(define-private (job-completed (job-id uint))
  (begin
    (var-set job-completed-event { job-id: job-id })
    { job-id: job-id }
  ))

(define-private (job-paid (job-id uint) (freelancer principal) (amount uint))
  (begin
    (var-set job-paid-event { job-id: job-id, freelancer: freelancer, amount: amount })
    { job-id: job-id, freelancer: freelancer, amount: amount }
  ))

;; ------------------------------
;; PRIVATE UTILS
;; ------------------------------
(define-private (only-admin)
  (if (is-eq tx-sender admin)
      (ok true)
      ERR_NOT_AUTHORIZED))

;; ------------------------------
;; CORE FUNCTIONS
;; ------------------------------

;; . Post a new job
(define-public (post-job (description (string-ascii 200)) (amount uint))
  (begin
    (if (<= amount u0)
        ERR_INVALID_AMOUNT
        (let ((job-id (+ u1 (var-get job-counter))))
          (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
          (map-set jobs { id: job-id }
            {
              client: tx-sender,
              freelancer: none,
              description: description,
              amount: amount,
              completed: false,
              paid: false
            })
          (var-set job-counter job-id)
          (print (job-posted job-id tx-sender amount))
          (ok job-id)
        )
    )
  )
)

;; Freelancer accepts a job
(define-public (accept-job (job-id uint))
  (let ((job (map-get? jobs { id: job-id })))
    (if (is-none job)
        ERR_JOB_NOT_FOUND
        (let ((data (unwrap-panic job)))
          (if (is-some (get freelancer data))
              ERR_JOB_ALREADY_TAKEN
              (begin
                (map-set jobs { id: job-id }
                  (merge data { freelancer: (some tx-sender) }))
                (print (job-accepted job-id tx-sender))
                (ok job-id)
              )
          )
        )
    )
  )
)

;;  Mark job as completed (by freelancer)
(define-public (mark-completed (job-id uint))
  (let ((job (map-get? jobs { id: job-id })))
    (if (is-none job)
        ERR_JOB_NOT_FOUND
        (let ((data (unwrap-panic job)))
          (if (not (is-some (get freelancer data)))
              ERR_NOT_FREELANCER
              (if (is-eq (some tx-sender) (get freelancer data))
                  (begin
                    (map-set jobs { id: job-id }
                      (merge data { completed: true }))
                    (print (job-completed job-id))
                    (ok true)
                  )
                  ERR_NOT_FREELANCER
              )
          )
        )
    )
  )
)

;;. Client releases payment after confirming completion
(define-public (release-payment (job-id uint))
  (let ((job (map-get? jobs { id: job-id })))
    (if (is-none job)
        ERR_JOB_NOT_FOUND
        (let ((data (unwrap-panic job)))
          (if (not (is-eq (get client data) tx-sender))
              ERR_NOT_CLIENT
              (if (not (get completed data))
                  ERR_JOB_NOT_COMPLETED
                  (if (get paid data)
                      ERR_ALREADY_COMPLETED
                      (let ((freelancer (default-to tx-sender (get freelancer data))))
                        (try! (stx-transfer? (get amount data) (as-contract tx-sender) freelancer))
                        (map-set jobs { id: job-id } (merge data { paid: true }))
                        (print (job-paid job-id freelancer (get amount data)))
                        (ok "Payment released")
                      )
                  )
              )
          )
        )
    )
  )
)

;; Admin refund (if dispute)
(define-public (admin-refund (job-id uint))
  (begin
    (try! (only-admin))
    (let ((job (map-get? jobs { id: job-id })))
      (if (is-none job)
          ERR_JOB_NOT_FOUND
          (let ((data (unwrap-panic job)))
            (if (get paid data)
                ERR_ALREADY_COMPLETED
                (begin
                  (try! (stx-transfer? (get amount data) (as-contract tx-sender) (get client data)))
                  (map-set jobs { id: job-id } (merge data { paid: true }))
                  (ok "Refunded to client")
                )
            )
          )
      )
    )
  )
)

;; ------------------------------
;; READ-ONLY FUNCTIONS
;; ------------------------------

;; Get job details
(define-read-only (get-job (job-id uint))
  (map-get? jobs { id: job-id })
)

;; Get total number of jobs
(define-read-only (get-job-count)
  (ok (var-get job-counter))
)
