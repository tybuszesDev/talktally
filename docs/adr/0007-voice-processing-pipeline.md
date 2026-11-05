# ADR-0007: Voice processing pipeline

- Status: Accepted
- Date: 2026-11-05

## Context

The phone records a dictation in Polish. The audio must be transcribed, turned into structured changes (ADR-0008) and returned to the user for review. Each step can fail or take time (transcription of a 3-minute file takes tens of seconds). Mobile networks are unreliable, and the user may record without a connection.

## Decision

An asynchronous pipeline orchestrated by **AWS Step Functions (Standard workflow)**.

1. **Create the entry.** The app calls the `createEntryUpload(projectId)` mutation. It returns an `entryId` and a short-lived presigned S3 `PUT` URL. The entry status is `UPLOADING`.
   - Offline: the app keeps the recording in a local queue and runs this step when the network returns.
2. **Upload.** The app uploads the audio (AAC in M4A, mono, 16 kHz, 32–64 kbps, which is enough for speech) to `s3://<audio-bucket>/users/<sub>/entries/<entryId>.m4a`.
3. **Start.** S3 sends an `Object Created` event to EventBridge. An EventBridge rule starts the state machine with the execution name `entryId`, so a duplicate event cannot start a second run.
4. **Transcribe.** The state machine starts an Amazon Transcribe batch job (`pl-PL` by default, from user settings) and polls its status with a `Wait` loop. Status `TRANSCRIBING`. Later: a custom vocabulary per template (product names such as "Atlas", "Geoflex").
5. **Extract.** A Lambda loads the transcript and the project context and calls Bedrock (ADR-0008). Status `EXTRACTING`.
6. **Apply or review.** A Lambda applies high-confidence operations and stores the rest as pending. Status `APPLIED` or `NEEDS_REVIEW`.
7. **Notify.** Every status change calls the IAM-only publish mutation, so web and mobile update in real time (ADR-0005).

Failure handling:

- Every task has retries with backoff. A `Catch` sets the status to `FAILED` with a reason.
- The user can retry a failed entry. Retrying from the stored transcript skips transcription.

Other rules:

- **Text entries** start the same state machine at step 5. They are used by the web app, by tests and as a fallback.
- **Quotas** (maximum audio length, minutes per day) are checked in step 1.
- **Retention:** raw audio stays in S3 Standard for 30 days, where the app can play it. Then a lifecycle rule moves it to S3 Glacier Deep Archive.
  - Audio is kept so entries can be re-processed with better models, and real recordings can feed the evaluation set (ADR-0008).
  - Restoring from Deep Archive takes up to 48 hours, so the app shows older audio as archived. On-demand restore is post-MVP.
  - Deleting an entry deletes its audio, also from the archive.
  - Transcripts stay in DynamoDB.

## Consequences

- Each step is visible in the Step Functions console, which helps debugging and looks good in a demo.
- Polling Transcribe costs a few state transitions per minute of audio. That stays inside the free tier at this volume.
- The user waits for the whole pipeline; there is no live transcript while speaking.

## Alternatives considered

- **Amazon Transcribe streaming from the phone:** live text while speaking, but it needs a streaming connection from the device and is harder to retry. Post-MVP.
- **Callback with a task token** (Transcribe completion event resumes the workflow): no polling, but more moving parts. Can replace the polling loop later.
- **Chained Lambdas without Step Functions:** fewer services, but retries, timeouts and status tracking would be hand-written.
- **On-device speech recognition:** free, but quality for Polish varies by device and it does not use AWS.
