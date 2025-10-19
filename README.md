# freelance-escrow

A simple decentralized escrow Clarity contract for freelance jobs on the Stacks blockchain. Clients post jobs with an STX deposit, freelancers accept and complete jobs, and clients release payment. An admin account can issue refunds in disputes.

Repository layout
- contracts/freelance-escrow.clar — Clarity smart contract (job storage, lifecycle, events, admin refund)
- tests/ — (optional) place for Clarinet tests
- README.md — this file

Features
- Post a job with description and STX amount (client funds locked on post)
- Freelancers accept available jobs
- Freelancer marks job completed
- Client releases payment to freelancer after confirming completion
- Admin-only refund for disputed/unreleased jobs
- Read-only views for job details and total jobs

Quick contract summary
- Storage:
  - map `jobs` keyed by job id storing client, optional freelancer, description, amount, completed, paid
  - data-var `job-counter` increments for each job
  - admin is set to the deploying tx-sender
- Events (as data-vars): job-posted, job-accepted, job-completed, job-paid
- Errors:
  - u100 ERR_NOT_CLIENT
  - u101 ERR_NOT_FREELANCER
  - u102 ERR_JOB_NOT_FOUND
  - u103 ERR_JOB_ALREADY_TAKEN
  - u104 ERR_JOB_NOT_COMPLETED
  - u105 ERR_ALREADY_COMPLETED
  - u106 ERR_INVALID_AMOUNT
  - u107 ERR_NOT_AUTHORIZED
- Accept a job (freelancer):
