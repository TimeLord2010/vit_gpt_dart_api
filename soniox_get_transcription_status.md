# Get transcription

URL: /stt/api-reference/transcriptions/get_transcription

Retrieves detailed information about a specific transcription.

## Get transcription

**Endpoint:** `GET /v1/transcriptions/{transcription_id}`

Retrieves detailed information about a specific transcription.

### Parameters

- `transcription_id` (path) (Required):

### Responses

- **200**: Transcription details.

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

- **404**: Transcription not found.

Error types:

- `transcription_not_found`: Transcription could not be found.

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
