# Manual finalization

URL: /stt/rt/manual-finalization

Learn how manual finalization works.

import { LuTriangleAlert } from "react-icons/lu";

## Overview

Soniox supports **manual finalization** in addition to automatic mechanisms like
[endpoint detection](/stt/rt/endpoint-detection). Manual finalization
gives you precise control over when audio should be finalized — useful for:

- Push-to-talk systems.
- Client-side voice activity detection (VAD).
- Segment-based transcription pipelines.
- Applications where automatic endpoint detection is not ideal.

---

## How to finalize

Send a control message over the WebSocket connection:

```json
{ "type": "finalize" }
```

When received:

- Soniox finalizes all audio up to that point.
- All tokens from that audio are returned with `"is_final": true`.
- The model emits a special marker token:

```json
{ "text": "<fin>", "is_final": true }
```

The `<fin>` token signals that finalization is complete.

---

## Key points

- You can call `finalize` multiple times per session.
- You may continue streaming audio after each `finalize` call.
- The `<fin>` token is always returned as final and can be used to trigger downstream processing.
- Do not send `finalize` too frequently (every few seconds is fine; too often may cause disconnections).
- <LuTriangleAlert className="inline text-fd-card align-text-bottom size-6 fill-orange-400" /> Call `finalize` only after sending approximately 200ms of silence following
  the end of speech to balance high accuracy and low latency. Adjust the VAD sensitivity accordingly. Triggering `finalize` too early can degrade model accuracy.
- <LuTriangleAlert className="inline text-fd-card align-text-bottom size-6 fill-orange-400" /> You are charged for the **full stream duration,** not just the audio processed.

---

## Connection keepalive

Combine with [connection keepalive](/stt/rt/connection-keepalive): use keepalive messages to prevent timeouts when no audio is being sent (e.g., during long pauses).
