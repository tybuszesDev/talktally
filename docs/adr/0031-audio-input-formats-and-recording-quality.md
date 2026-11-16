# ADR-0031: Audio input formats and recording quality

- Status: Accepted
- Date: 2026-11-16
- Amends: [ADR-0007](0007-voice-processing-pipeline.md) (the audio format in step 2 and the object key)

## Context

ADR-0007 fixed one upload format: AAC in M4A, mono, 16 kHz, 32–64 kbps, "which is enough for speech". The F-14 spike ([results](../spikes/F-14-transcribe-and-bedrock.md)) transcribed three real dictations twice, as recorded (AAC, 48 kHz) and converted to the ADR-0007 format. The 16 kHz copies had lower word confidence in all three recordings, and one meaningful word was lost ("grzejników" became "żyjików"). Three recordings are little evidence, but they point the same way as the AWS advice: "For best results, use a lossless format, such as FLAC or WAV with PCM 16-bit encoding" ([Transcribe data input](https://docs.aws.amazon.com/transcribe/latest/dg/how-input.html)).

Facts from the same page and the [Transcribe quotas](https://docs.aws.amazon.com/general/latest/gr/transcribe.html):

- Batch jobs accept AMR, FLAC, M4A, MP3, MP4, Ogg, WebM and WAV, with one or two channels, at 8,000 to 48,000 Hz. The sample rate parameter is optional; Transcribe detects it.
- A file may be up to 2 GB and 28,800 seconds long. The TalkTally quota is 10 minutes per entry (DOMAIN).

The owner wants the app to accept whatever audio it receives and the mobile app to record at the best quality it can. Recordings may also come from other sources later, such as files from the iPhone Voice Memos app.

## Decision

- **The pipeline accepts every batch format Transcribe supports:** AMR, FLAC, M4A, MP3, MP4, Ogg, WebM and WAV. There is no server-side conversion.
  - `createEntryUpload` takes the content type of the recording. The presigned POST allows only these types and a size that fits the 10-minute quota in the largest allowed format.
  - The object key keeps the matching extension (`users/<sub>/entries/<entryId>.<ext>`), and the state machine passes the matching `MediaFormat` to Transcribe. The sample rate is not sent; Transcribe detects it.
  - A file Transcribe cannot read fails the entry with a reason the user can understand.
- **The mobile app records at the best quality the device and the recording library support for speech:** mono, the highest sample rate up to 48 kHz, a lossless format if the library supports it and the file stays within the upload limit, otherwise AAC at a high bitrate. F-41 chooses the exact settings from the library's documentation and records them in its pull request.

## Consequences

- Recognition gets the best input the phone can produce, and no conversion step is needed.
- Files are larger. Ten minutes of 48 kHz 16-bit mono WAV is about 58 MB, against under 3 MB for 32 kbps AAC. Uploads take longer on mobile networks, and the offline queue (F-41) holds more data. S3 storage stays small at one dictation a day, and audio moves to Glacier Deep Archive after 30 days (ADR-0007); F-41 checks the cost against the price list.
- The upload contract has a content type and a size limit per type; F-40 implements them.
- Playback of archived audio in the app must handle several formats.

## Alternatives considered

- **Keep 16 kHz AAC (ADR-0007):** small files, but slightly worse recognition in the spike and against the AWS advice.
- **One fixed high-quality format:** simpler contract, but rejects files from other sources, which the owner wants to accept.
- **Server-side conversion (for example AWS Elemental MediaConvert or ffmpeg in Lambda):** one format inside the pipeline, but another service or a large Lambda layer, and Transcribe already reads all common formats.
