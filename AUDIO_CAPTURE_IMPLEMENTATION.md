# Implementação de Captura de Áudio para TranscriptionEnd e RealtimeResponse

## Visão Geral

Este documento descreve a implementação da funcionalidade de captura e associação de áudio aos eventos `TranscriptionEnd` e `RealtimeResponse` no sistema de transcrição em tempo real, suportando tanto OpenAI nativo quanto Soniox.

## Problema Resolvido

Anteriormente, os eventos de transcrição e resposta não incluíam o áudio correspondente. Esta implementação adiciona a capacidade de capturar e associar o trecho de áudio exato a cada transcrição ou resposta, permitindo reprodução, análise ou armazenamento posterior.

## Arquitetura da Solução

### 1. Estruturas de Dados Modificadas

#### TranscriptionEnd (`lib/data/models/realtime_events/transcription/transcription_end.dart`)

```dart
class TranscriptionEnd {
  final List<int>? audioBytes; // Campo adicionado para armazenar áudio
  // ... outros campos
}
```

#### RealtimeResponse (`lib/data/models/realtime_events/realtime_response.dart`)

```dart
class RealtimeResponse {
  final List<int>? audioBytes; // Campo adicionado para armazenar áudio

  factory RealtimeResponse.fromMap(Map<String, dynamic> map) {
    return RealtimeResponse(
      // ... outros parâmetros
      audioBytes: map['audioBytes'] as List<int>?, // Processamento do áudio
    );
  }
}
```

### 2. Buffers de Áudio Implementados

No `OpenaiRealtimeRepository`, foram adicionados os seguintes buffers:

```dart
// Buffers para armazenar áudio temporariamente
final Map<String, List<int>> _userAudioBuffers = {};    // Áudio do usuário
final Map<String, List<int>> _aiAudioBuffers = {};      // Áudio da IA
final Map<String, List<int>> _sonioxAudioBuffers = {};  // Áudio do Soniox

// Rastreamento de IDs ativos
String? _currentUserItemId;      // ID do item atual do usuário
String? _currentAiResponseId;    // ID da resposta atual da IA
String? _currentSonioxItemId;    // ID do item atual do Soniox
```

## Fluxo de Implementação

### Para OpenAI Nativo

#### 1. Captura de Áudio do Usuário

```dart
void sendUserAudio(Uint8List audioData) {
  if (!useSoniox) {
    // Cria buffer temporário se não houver item ID ainda
    if (_currentUserItemId == null) {
      _currentUserItemId = '_temp_buffer';
    }

    // Armazena áudio no buffer
    _userAudioBuffers.putIfAbsent(_currentUserItemId!, () => []);
    _userAudioBuffers[_currentUserItemId!]!.addAll(audioData);

    // Envia para OpenAI
    var mapData = {
      "type": "input_audio_buffer.append",
      "audio": base64Encode(audioData),
    };
    socket?.sink.add(jsonEncode(mapData));
  }
}
```

#### 2. Transferência do Buffer Temporário

Quando o evento `input_audio_buffer.speech_started` é recebido:

```dart
'input_audio_buffer.speech_started': () async {
  String newItemId = data['item_id'];

  // Transfere áudio do buffer temporário para o buffer real
  if (_currentUserItemId == '_temp_buffer' &&
      _userAudioBuffers.containsKey('_temp_buffer')) {
    _userAudioBuffers[newItemId] = _userAudioBuffers['_temp_buffer'] ?? [];
    _userAudioBuffers.remove('_temp_buffer');
  }

  _currentUserItemId = newItemId;
  // ... resto do código
}
```

#### 3. Inclusão do Áudio na Transcrição

```dart
'conversation.item.input_audio_transcription.completed': () async {
  String itemId = data['item_id'];

  // Recupera o áudio do buffer
  List<int>? audioBytes = _userAudioBuffers[itemId];

  var transcriptionEnd = TranscriptionEnd(
    id: itemId,
    content: content,
    audioBytes: audioBytes, // Inclui o áudio
    // ... outros parâmetros
  );

  // Limpa o buffer após uso
  _userAudioBuffers.remove(itemId);
}
```

### Para Soniox

#### 1. Captura de Áudio

```dart
void sendUserAudio(Uint8List audioData) {
  if (useSoniox) {
    // Armazena áudio para transcrições do Soniox
    if (_currentSonioxItemId != null) {
      _sonioxAudioBuffers.putIfAbsent(_currentSonioxItemId!, () => []);
      _sonioxAudioBuffers[_currentSonioxItemId!]!.addAll(audioData);
    }

    // Envia para Soniox
    if (_sonioxSocket != null) {
      _sonioxSocket?.sink.add(audioData);
    }
  }
}
```

#### 2. Inicialização de Buffers para Nova Transcrição

```dart
void _processSonioxRealtimeMessage(dynamic event) {
  // ... processamento de tokens

  if (isFinal) {
    // Inicializa ID e buffers para nova transcrição
    if (_currentSonioxItemId == null) {
      _currentSonioxItemId = _generateItemId();
      _sonioxTokenBuffers[_currentSonioxItemId!] = StringBuffer();
      _sonioxAudioBuffers[_currentSonioxItemId!] = [];
    }
    _sonioxTokenBuffers[_currentSonioxItemId!]!.write(text);
  }
}
```

#### 3. Inclusão do Áudio na Finalização

```dart
void _handleSonioxFinalization() {
  final itemId = _currentSonioxItemId!;

  // Recupera o áudio do buffer
  List<int>? audioBytes = _sonioxAudioBuffers[itemId];

  var transcriptionEnd = TranscriptionEnd(
    id: itemId,
    content: transcript,
    audioBytes: audioBytes, // Inclui o áudio
    // ... outros parâmetros
  );

  // Limpa buffers
  _sonioxAudioBuffers.remove(itemId);
  _currentSonioxItemId = null;
}
```

### Para Áudio da IA

#### 1. Captura Durante Recebimento

```dart
'response.audio.delta': () async {
  String responseId = data['response_id'];

  if (!isAiSpeaking) {
    _currentAiResponseId = responseId;
    _aiAudioBuffers[responseId] = [];
  }

  // Decodifica e armazena áudio
  String base64Data = data['delta'];
  List<int> audioBytes = base64Decode(base64Data);
  _aiAudioBuffers[responseId]?.addAll(audioBytes);

  // ... envio do evento
}
```

#### 2. Inclusão na TranscriptionEnd da IA

```dart
'response.audio_transcript.done': () async {
  // Recupera o áudio da resposta atual
  List<int>? audioBytes = _currentAiResponseId != null
      ? _aiAudioBuffers[_currentAiResponseId!]
      : null;

  onTranscriptionEndController.add(TranscriptionEnd(
    audioBytes: audioBytes, // Inclui o áudio
    // ... outros parâmetros
  ));
}
```

#### 3. Inclusão no RealtimeResponse

```dart
'response.done': () async {
  var map = data['response'];

  // Adiciona áudio ao mapa de resposta
  if (_currentAiResponseId != null &&
      _aiAudioBuffers[_currentAiResponseId!] != null) {
    map['audioBytes'] = _aiAudioBuffers[_currentAiResponseId!];
  }

  var response = RealtimeResponse.fromMap(map);

  // Limpa buffer após uso
  if (_currentAiResponseId != null) {
    _aiAudioBuffers.remove(_currentAiResponseId);
    _currentAiResponseId = null;
  }
}
```

## Gerenciamento de Memória

Para evitar vazamentos de memória, todos os buffers são:

1. **Limpos após uso**: Cada buffer é removido após o áudio ser incluído no evento
2. **Limpos no fechamento**: O método `close()` limpa todos os buffers

```dart
void close() {
  // ... outros códigos de limpeza

  _userAudioBuffers.clear();
  _aiAudioBuffers.clear();
  _sonioxAudioBuffers.clear();
  _currentUserItemId = null;
  _currentAiResponseId = null;
  _currentSonioxItemId = null;
}
```

## Como Usar

### Exemplo de Uso

```dart
// Escutando transcrições com áudio
realtimeRepository.onTranscriptionEnd.listen((transcriptionEnd) {
  if (transcriptionEnd.audioBytes != null) {
    // Acessa o áudio da transcrição
    List<int> audioData = transcriptionEnd.audioBytes!;

    // Exemplo: Salvar em arquivo
    File audioFile = File('transcription_${transcriptionEnd.id}.pcm');
    await audioFile.writeAsBytes(audioData);

    // Exemplo: Reproduzir o áudio
    audioPlayer.playBytes(audioData);

    print('Transcrição: ${transcriptionEnd.content}');
    print('Tamanho do áudio: ${audioData.length} bytes');
  }
});

// Escutando respostas com áudio
realtimeRepository.onResponse.listen((response) {
  if (response.audioBytes != null) {
    // Acessa o áudio completo da resposta
    List<int> audioData = response.audioBytes!;

    // Processar o áudio conforme necessário
    processAudioResponse(audioData);
  }
});
```

## Vantagens da Implementação

1. **Sincronia Perfeita**: O áudio está sempre sincronizado com sua transcrição correspondente
2. **Flexibilidade**: Funciona tanto com OpenAI nativo quanto Soniox sem mudanças no código do cliente
3. **Eficiência**: Buffers temporários garantem que nenhum áudio seja perdido
4. **Gerenciamento de Memória**: Limpeza automática previne vazamentos
5. **Facilidade de Uso**: API simples através da propriedade `audioBytes`

## Considerações Técnicas

### Formato do Áudio

- **OpenAI**: PCM 16-bit, 24kHz, mono
- **Soniox**: PCM 16-bit, 24kHz, mono
- **Armazenamento**: `List<int>` (bytes brutos)

### Performance

- Buffers são mantidos apenas durante o processamento ativo
- Limpeza imediata após uso minimiza uso de memória
- Transferência eficiente de buffers temporários

### Compatibilidade

A implementação é totalmente compatível com:

- Flutter/Dart
- Diferentes modos de operação (OpenAI/Soniox)
- Modo press-to-talk e detecção automática de fim de fala

## Conclusão

Esta implementação fornece uma solução robusta e eficiente para capturar e associar áudio aos eventos de transcrição e resposta, mantendo a flexibilidade para trabalhar com diferentes provedores de transcrição e garantindo que o áudio esteja sempre disponível quando necessário.
