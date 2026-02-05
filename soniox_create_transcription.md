# Create transcription

URL: /stt/api-reference/transcriptions/create_transcription

Creates a new transcription.

## Create transcription

**Endpoint:** `POST /v1/transcriptions`

Creates a new transcription.

### Request Body

Content-Type: `application/json` (Required)

Schema (YAML Structural Definition):

```yaml
properties:
    model:
        description: Speech-to-text model to use for the transcription.
        maxLength: 32
        type: string
    audio_url:
        anyOf:
            - maxLength: 4096
              pattern: ^https?://[^\s]+$
              type: string
            - type: "null"
        description: >-
            URL of the audio file to transcribe. Cannot be specified if `file_id` is
            specified.
    file_id:
        anyOf:
            - format: uuid
              type: string
            - type: "null"
        description: >-
            ID of the uploaded file to transcribe. Cannot be specified if `audio_url`
            is specified.
    language_hints:
        anyOf:
            - items:
                  maxLength: 10
                  type: string
              maxItems: 100
              type: array
            - type: "null"
        description: >-
            Expected languages in the audio. If not specified, languages are
            automatically detected.
    language_hints_strict:
        anyOf:
            - type: boolean
            - type: "null"
        description: When `true`, the model will rely more on language hints.
    enable_speaker_diarization:
        anyOf:
            - type: boolean
            - type: "null"
        description: >-
            When `true`, speakers are identified and separated in the transcription
            output.
    enable_language_identification:
        anyOf:
            - type: boolean
            - type: "null"
        description: When `true`, language is detected for each part of the transcription.
    translation:
        anyOf:
            - properties:
                  type:
                      enum:
                          - one_way
                          - two_way
                      type: string
                  target_language:
                      anyOf:
                          - type: string
                          - type: "null"
                  language_a:
                      anyOf:
                          - type: string
                          - type: "null"
                  language_b:
                      anyOf:
                          - type: string
                          - type: "null"
              required:
                  - type
              type: object
            - type: "null"
        description: Translation configuration.
    context:
        anyOf:
            - properties:
                  general:
                      anyOf:
                          - items:
                                properties:
                                    key:
                                        description: Item key (e.g. "Domain").
                                        type: string
                                    value:
                                        description: Item value (e.g. "medicine").
                                        type: string
                                required:
                                    - key
                                    - value
                                type: object
                            type: array
                          - type: "null"
                      description: General context items.
                  text:
                      anyOf:
                          - type: string
                          - type: "null"
                      description: Text context.
                  terms:
                      anyOf:
                          - items:
                                type: string
                            type: array
                          - type: "null"
                      description: Terms that might occur in speech.
                  translation_terms:
                      anyOf:
                          - items:
                                properties:
                                    source:
                                        description: Source term.
                                        type: string
                                    target:
                                        description: Target term to translate to.
                                        type: string
                                required:
                                    - source
                                    - target
                                type: object
                            type: array
                          - type: "null"
                      description: >-
                          Hints how to translate specific terms. Ignored if translation is
                          not enabled.
              type: object
            - type: string
            - type: "null"
        description: >-
            Additional context to improve transcription accuracy and formatting of
            specialized terms.
    webhook_url:
        anyOf:
            - maxLength: 256
              pattern: ^https?://[^\s]+$
              type: string
            - type: "null"
        description: >-
            URL to receive webhook notifications when transcription is completed or
            fails.
    webhook_auth_header_name:
        anyOf:
            - maxLength: 256
              type: string
            - type: "null"
        description: Name of the authentication header sent with webhook notifications.
    webhook_auth_header_value:
        anyOf:
            - maxLength: 256
              type: string
            - type: "null"
        description: Authentication header value sent with webhook notifications.
    client_reference_id:
        anyOf:
            - maxLength: 256
              type: string
            - type: "null"
        description: Optional tracking identifier string. Does not need to be unique.
required:
    - model
type: object
```

### Responses

- **201**: Created transcription.

Example (JSON):

```json
{
    "audio_duration_ms": 0,
    "audio_url": "https://soniox.com/media/examples/coffee_shop.mp3",
    "client_reference_id": "some_internal_id",
    "created_at": "2024-11-26T00:00:00Z",
    "error_message": null,
    "error_type": null,
    "file_id": null,
    "filename": "coffee_shop.mp3",
    "id": "73d4357d-cad2-4338-a60d-ec6f2044f721",
    "language_hints": ["en", "fr"],
    "model": "stt-async-preview",
    "status": "queued",
    "webhook_auth_header_name": "Authorization",
    "webhook_auth_header_value": "******************",
    "webhook_status_code": null,
    "webhook_url": "https://example.com/webhook"
}
```

Schema (YAML Structural Definition):

```yaml
description: A transcription.
properties:
    id:
        description: Unique identifier for the transcription request.
        format: uuid
        type: string
    status:
        description: Transcription status.
        enum:
            - queued
            - processing
            - completed
            - error
        type: string
    created_at:
        description: UTC timestamp indicating when the transcription was created.
        format: date-time
        type: string
    model:
        description: Speech-to-text model used for the transcription.
        type: string
    audio_url:
        anyOf:
            - type: string
            - type: "null"
        description: URL of the file being transcribed.
    file_id:
        anyOf:
            - format: uuid
              type: string
            - type: "null"
        description: ID of the file being transcribed.
    filename:
        description: Name of the file being transcribed.
        type: string
    language_hints:
        anyOf:
            - items:
                  type: string
              type: array
            - type: "null"
        description: >-
            Expected languages in the audio. If not specified, languages are
            automatically detected.
    enable_speaker_diarization:
        description: >-
            When `true`, speakers are identified and separated in the transcription
            output.
        type: boolean
    enable_language_identification:
        description: When `true`, language is detected for each part of the transcription.
        type: boolean
    audio_duration_ms:
        anyOf:
            - type: integer
            - type: "null"
        description: >-
            Duration of the audio in milliseconds. Only available after processing
            begins.
    error_type:
        anyOf:
            - type: string
            - type: "null"
        description: >-
            Error type if transcription failed. `null` for successful or in-progress
            transcriptions.
    error_message:
        anyOf:
            - type: string
            - type: "null"
        description: >-
            Error message if transcription failed. `null` for successful or
            in-progress transcriptions.
    webhook_url:
        anyOf:
            - type: string
            - type: "null"
        description: >-
            URL to receive webhook notifications when transcription is completed or
            fails.
    webhook_auth_header_name:
        anyOf:
            - type: string
            - type: "null"
        description: Name of the authentication header sent with webhook notifications.
    webhook_auth_header_value:
        anyOf:
            - type: string
            - type: "null"
        description: >-
            Authentication header value. Always returned masked as
            `******************`.
    webhook_status_code:
        anyOf:
            - type: integer
            - type: "null"
        description: >-
            HTTP status code received from your server when webhook was delivered.
            `null` if not yet sent.
    client_reference_id:
        anyOf:
            - type: string
            - type: "null"
        description: Tracking identifier string.
required:
    - id
    - status
    - created_at
    - model
    - filename
    - enable_speaker_diarization
    - enable_language_identification
type: object
```

- **400**: Invalid request.

Error types:

- `invalid_request`: Invalid request.

Schema (YAML Structural Definition):

```yaml
properties:
    status_code:
        type: integer
    error_type:
        type: string
    message:
        type: string
    validation_errors:
        items:
            properties:
                error_type:
                    type: string
                location:
                    type: string
                message:
                    type: string
            required:
                - error_type
                - location
                - message
            type: object
        type: array
    request_id:
        type: string
required:
    - status_code
    - error_type
    - message
    - validation_errors
    - request_id
type: object
```

- **401**: Authentication error.

Schema (YAML Structural Definition):

```yaml
properties:
    status_code:
        type: integer
    error_type:
        type: string
    message:
        type: string
    validation_errors:
        items:
            properties:
                error_type:
                    type: string
                location:
                    type: string
                message:
                    type: string
            required:
                - error_type
                - location
                - message
            type: object
        type: array
    request_id:
        type: string
required:
    - status_code
    - error_type
    - message
    - validation_errors
    - request_id
type: object
```

- **500**: Internal server error.

Schema (YAML Structural Definition):

```yaml
properties:
    status_code:
        type: integer
    error_type:
        type: string
    message:
        type: string
    validation_errors:
        items:
            properties:
                error_type:
                    type: string
                location:
                    type: string
                message:
                    type: string
            required:
                - error_type
                - location
                - message
            type: object
        type: array
    request_id:
        type: string
required:
    - status_code
    - error_type
    - message
    - validation_errors
    - request_id
type: object
```
