# ADR-0031: Audio input formats and recording quality

- Status: Accepted
- Date: 2026-11-16
- Amends: [ADR-0007](0007-voice-processing-pipeline.md) (the upload method in step 1, the audio format and object key in step 2, the event rule in step 3, and the quota enforcement before transcription)

## Context

ADR-0007 fixed one upload format: AAC in M4A, mono, 16 kHz, 32–64 kbps, "which is enough for speech". The F-14 spike ([results](../spikes/F-14-transcribe-and-bedrock.md)) transcribed three real dictations twice, as recorded (AAC, 48 kHz) and converted to the ADR-0007 format. The 16 kHz copies had lower word confidence in all three recordings, and one meaningful word was lost ("grzejników" became "żyjików"). Three recordings are little evidence, but they point the same way as the AWS advice: "For best results, use a lossless format, such as FLAC or WAV with PCM 16-bit encoding" ([Transcribe data input](https://docs.aws.amazon.com/transcribe/latest/dg/how-input.html)).

Facts from the same page and the [Transcribe quotas](https://docs.aws.amazon.com/general/latest/gr/transcribe.html):

- Batch jobs accept AMR, FLAC, M4A, MP3, MP4, Ogg, WebM and WAV, with one or two channels, at 8,000 to 48,000 Hz. The sample rate parameter is optional; Transcribe detects it.
- A file may be up to 2 GB and 28,800 seconds long. The TalkTally quota is 10 minutes per entry (DOMAIN).

The owner wants the app to accept whatever audio it receives and the mobile app to record at the best quality it can. Recordings may also come from other sources later, such as files from the iPhone Voice Memos app.

## Decision

- **The pipeline accepts every batch format Transcribe supports:** AMR, FLAC, M4A, MP3, MP4, Ogg, WebM and WAV. There is no server-side conversion.
  - **Upload with a presigned POST**, which replaces the presigned PUT URL of ADR-0007 step 1 (DOMAIN and F-40 already describe a POST). `createEntryUpload` takes the content type of the recording, and the POST policy allows exactly that type and a size range (`content-length-range`) that fits the 10-minute quota in the largest allowed format ([POST policy conditions](https://docs.aws.amazon.com/AmazonS3/latest/developerguide/sigv4-HTTPPOSTConstructPolicy.html)).
  - **The pipeline works on its own copy.** The POST policy allows only the entry's upload key (`uploads/<sub>/<entryId>.<ext>`), and the EventBridge rule matches only that prefix. The first pipeline step copies the upload to the archive key `users/<sub>/entries/<entryId>.<ext>`, which clients cannot write, and deletes the upload. The duration check, transcription and playback use only the copy, so uploading again with the same POST policy cannot change the checked file. The state machine passes the `MediaFormat` matching the extension to Transcribe; the sample rate is not sent, Transcribe detects it.
  - **The duration is checked on the server before transcription.** The size limit does not bound the length of compressed audio (a low bitrate fits hours into the same size), and a duration reported by the client is not trusted. A pipeline step reads the duration from the copied file itself before the Transcribe job starts and fails the entry when it exceeds the per-entry quota. F-42 chooses how to read the duration of each accepted format.
  - **The daily quota is reserved atomically.** The measured duration is added to the user's daily usage item (DOMAIN, `USAGE#<date>`) with a conditional update that succeeds only while the remaining dictation minutes cover it. Transcribe starts only after the reservation succeeds; otherwise the entry fails with "daily limit reached". Concurrent uploads therefore cannot exceed the daily limit together. The check in `createEntryUpload` (ADR-0007, step 1) stays as an early rejection, not as the enforcement.
  - A file Transcribe cannot read, or whose duration cannot be read, fails the entry with a reason the user can understand.
- **The mobile app records at the best quality the device and the recording library support for speech:** mono, the highest sample rate up to 48 kHz, a lossless format if the library supports it and the file stays within the upload limit, otherwise AAC at a high bitrate. F-41 chooses the exact settings from the library's documentation and records them in its pull request.

## Consequences

- Recognition gets the best input the phone can produce, and no conversion step is needed.
- Files are larger. Ten minutes of 48 kHz 16-bit mono WAV is about 58 MB, against under 3 MB for 32 kbps AAC. Uploads take longer on mobile networks, and the offline queue (F-41) holds more data. S3 storage stays small at one dictation a day, and audio moves to Glacier Deep Archive after 30 days (ADR-0007); F-41 checks the cost against the price list.
- The upload contract has a content type and a size limit; F-40 implements them. The pipeline gains three steps before transcription (F-42): copy the upload, read its duration, reserve the quota. They protect the quotas and the Transcribe cost, also against a second upload with the same policy and against concurrent uploads.
- Playback of archived audio in the app must handle several formats.

## Alternatives considered

- **Keep 16 kHz AAC (ADR-0007):** small files, but slightly worse recognition in the spike and against the AWS advice.
- **One fixed high-quality format:** simpler contract, but rejects files from other sources, which the owner wants to accept.
- **Pinning the S3 version ID of the upload** for the duration check and the transcription: the same protection against a second upload, but it needs bucket versioning, which makes deleting an entry's audio (F-48) harder. A copy to a key that clients cannot write needs no versioning.
- **Server-side conversion (for example AWS Elemental MediaConvert or ffmpeg in Lambda):** one format inside the pipeline, but another service or a large Lambda layer, and Transcribe already reads all common formats.
