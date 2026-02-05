# Upload file

URL: /stt/api-reference/files/upload_file

Uploads a new file.

## Upload file

**Endpoint:** `POST /v1/files`

Uploads a new file.

### Request Body

Content-Type: `multipart/form-data` (Required)

Schema (YAML Structural Definition):

```yaml
type: object
properties:
    client_reference_id:
        anyOf:
            - maxLength: 256
              type: string
            - type: "null"
        description: Optional tracking identifier string. Does not need to be unique.
    file:
        description: >-
            The file to upload. Original file name will be used unless a custom
            filename is provided.
        format: binary
        type: string
required:
    - file
```

### Responses

- **201**: Uploaded file.

Example (JSON):

```json
{
    "client_reference_id": "some_internal_id",
    "created_at": "2024-11-26T00:00:00Z",
    "filename": "example.mp3",
    "id": "84c32fc6-4fb5-4e7a-b656-b5ec70493753",
    "size": 123456
}
```

Schema (YAML Structural Definition):

```yaml
description: File metadata.
properties:
    id:
        description: Unique identifier of the file.
        format: uuid
        type: string
    filename:
        description: Name of the file.
        type: string
    size:
        description: Size of the file in bytes.
        type: integer
    created_at:
        description: UTC timestamp indicating when the file was uploaded.
        format: date-time
        type: string
    client_reference_id:
        anyOf:
            - type: string
            - type: "null"
        description: Tracking identifier string.
required:
    - id
    - filename
    - size
    - created_at
type: object
```

- **400**: Invalid request.

Error types:

- `invalid_request`:
    - Invalid request.
    - Exceeded maximum file size (maximum is 1073741824 bytes).

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
