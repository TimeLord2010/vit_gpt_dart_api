# Get transcription transcript

URL: /stt/api-reference/transcriptions/get_transcription_transcript

Retrieves the full transcript text and detailed tokens for a completed transcription. Only available for successfully completed transcriptions.

## Get transcription transcript

**Endpoint:** `GET /v1/transcriptions/{transcription_id}/transcript`

Retrieves the full transcript text and detailed tokens for a completed transcription. Only available for successfully completed transcriptions.

### Parameters

- `transcription_id` (path) (Required):

### Responses

- **200**: Transcription transcript.

Example (JSON):

```json
{
    "id": "19b6d61d-02db-4c25-bc71-b4094dc310c8",
    "text": "Hello",
    "tokens": [
        {
            "confidence": 0.95,
            "end_ms": 90,
            "start_ms": 10,
            "text": "Hel"
        },
        {
            "confidence": 0.98,
            "end_ms": 160,
            "start_ms": 110,
            "text": "lo"
        }
    ]
}
```

Schema (YAML Structural Definition):

```yaml
description: The transcription text.
properties:
    id:
        description: Unique identifier of the transcription this transcript belongs to.
        format: uuid
        type: string
    text:
        description: Complete transcribed text content.
        type: string
    tokens:
        description: List of detailed token information with timestamps and metadata.
        items:
            description: The transcript token.
            example:
                confidence: 0.95
                end_ms: 90
                start_ms: 10
                text: Hel
            properties:
                text:
                    description: Token text content.
                    type: string
                start_ms:
                    description: Start time of the token in milliseconds.
                    type: integer
                end_ms:
                    description: End time of the token in milliseconds.
                    type: integer
                confidence:
                    description: Confidence score of the token, between 0.0 and 1.0.
                    type: number
                speaker:
                    anyOf:
                        - type: string
                        - type: "null"
                    description: >-
                        Speaker identifier. Only present when speaker diarization is
                        enabled.
                language:
                    anyOf:
                        - type: string
                        - type: "null"
                    description: >-
                        Detected language code for this token. Only present when language
                        identification is enabled.
                is_audio_event:
                    anyOf:
                        - type: boolean
                        - type: "null"
                    description: >-
                        Boolean indicating if this token represents an audio event. Only
                        present when audio event detection is enabled.
                translation_status:
                    anyOf:
                        - type: string
                        - type: "null"
                    description: >-
                        Translation status ("none", "original" or "translation"). Only when
                        if translation is enabled.
            required:
                - text
                - start_ms
                - end_ms
                - confidence
            type: object
        type: array
required:
    - id
    - text
    - tokens
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

- **409**: Invalid transcription state.

Error types:

- `transcription_invalid_state`:
    - Can only get transcript with completed status.
    - File transcription has failed.
    - Transcript no longer available.

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
