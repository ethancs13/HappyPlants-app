import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:happy_plants/models/care_log.dart';
import 'package:happy_plants/models/plant.dart';
import 'package:happy_plants/models/plant_photo.dart';
import 'package:happy_plants/repositories/care_log_repository.dart';
import 'package:happy_plants/repositories/chat_repository.dart';
import 'package:happy_plants/repositories/plant_photo_repository.dart';
import 'package:happy_plants/repositories/plant_repository.dart';
import 'package:happy_plants/repositories/settings_repository.dart';
import 'package:happy_plants/services/gemini_service.dart';
import 'package:happy_plants/services/notification_service.dart';
import 'package:happy_plants/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Data ─────────────────────────────────────────────────────────────────────

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isContext;
  final Uint8List? imageBytes;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isContext = false,
    this.imageBytes,
  });

  _ChatMessage copyWith({String? text}) => _ChatMessage(
        text: text ?? this.text,
        isUser: isUser,
        isContext: isContext,
        imageBytes: imageBytes,
      );
}

// ── Screen ───────────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  final _messages = <_ChatMessage>[];
  GeminiService? _gemini;
  ChatRepository? _chatRepo;
  SettingsRepository? _settingsRepo;

  bool _isStreaming = false;
  bool _isLoading = true;
  Uint8List? _pendingImage;

  /// Image bytes from the message currently being streamed.
  /// Available to the function-call handler for add_photo.
  Uint8List? _currentImageBytes;

  List<Plant> _allPlants = [];
  Map<int, String> _coverPhotos = {};
  Plant? _contextPlant;
  String _botName = 'PlantBot';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final chatRepo = await ChatRepository.create();
    final settingsRepo = await SettingsRepository.create();
    final plantRepo = await PlantRepository.create();

    final botName = await settingsRepo.get('bot_name') ?? 'PlantBot';
    final savedMessages = await chatRepo.getMessages();
    final savedHistory = await chatRepo.getGeminiHistory();
    final plants = await plantRepo.getAll();
    final photoRepo = await PlantPhotoRepository.create();
    final coverPhotos = await photoRepo.getCoverPhotoMap();

    final gemini = await GeminiService.create(
      plants: plants,
      botName: botName,
      resumedHistory: savedHistory,
    );

    if (!mounted) return;
    setState(() {
      _chatRepo = chatRepo;
      _settingsRepo = settingsRepo;
      _botName = botName;
      _allPlants = plants;
      _coverPhotos = coverPhotos;
      _gemini = gemini;
      _isLoading = false;

      if (savedMessages.isEmpty) {
        _messages.add(_ChatMessage(
          text:
              "Hi! I'm $_botName. I can identify plants from photos, "
              "diagnose ailments, and answer any plant care questions. "
              "Share a photo or ask me anything!",
          isUser: false,
        ));
      } else {
        for (final m in savedMessages) {
          _messages.add(_ChatMessage(
            text: m.text,
            isUser: m.isUser,
            isContext: m.isContext,
          ));
        }
      }
    });
    _scrollToBottom();
  }

  // ── Bot renaming ─────────────────────────────────────────────────────────

  Future<void> _renameBotDialog() async {
    if (_isLoading) return;

    // Use a ValueNotifier so the dialog can read the latest text on Save
    // without holding a TextEditingController that we'd need to dispose.
    final initialName = _botName;
    String pendingName = initialName;

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: initialName);
        return AlertDialog(
          title: const Text('Name your assistant'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(hintText: 'e.g. Fern, Leafy, Sprout'),
            onChanged: (v) => pendingName = v,
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, pendingName.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (newName == null || newName.isEmpty || newName == _botName) return;
    setState(() => _botName = newName);
    await _settingsRepo?.set('bot_name', newName);
  }

  // ── Plant picker ─────────────────────────────────────────────────────────

  Future<void> _showPlantPicker() async {
    if (_allPlants.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Select a plant for context',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_contextPlant != null)
                      ListTile(
                        leading: const Icon(Icons.cancel_outlined,
                            color: AppColors.textMuted),
                        title: const Text('Remove plant context'),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _contextPlant = null);
                        },
                      ),
                    ..._allPlants.map((p) => ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _coverPhotos.containsKey(p.id)
                                ? Image.file(
                                    File(_coverPhotos[p.id]!),
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, e, s) =>
                                        _plantIconFallback(),
                                  )
                                : _plantIconFallback(),
                          ),
                          title: Text(p.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(p.species),
                          trailing: _contextPlant?.id == p.id
                              ? const Icon(Icons.check_circle,
                                  color: AppColors.forest, size: 20)
                              : null,
                          onTap: () {
                            Navigator.pop(context);
                            _selectPlant(p);
                          },
                        )),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectPlant(Plant plant) async {
    final logRepo = await CareLogRepository.create();
    final logs = await logRepo.getByPlantId(plant.id!);
    if (!mounted) return;

    setState(() => _contextPlant = plant);

    final buf = StringBuffer()
      ..writeln(
          'I want to discuss my plant "${plant.name}" (${plant.species}).')
      ..writeln('Watering schedule: every ${plant.wateringIntervalDays} days.')
      ..writeln(plant.lastWateredDate != null
          ? 'Last watered: ${_formatDate(plant.lastWateredDate!)}.'
          : 'Never been watered yet.')
      ..writeln(plant.lastFertilizedDate != null
          ? 'Last fertilised: ${_formatDate(plant.lastFertilizedDate!)}.'
          : 'Never been fertilised.')
      ..writeln(plant.isOverdueForWater
          ? 'Status: OVERDUE for watering.'
          : 'Watering status: up to date.');
    if (plant.notes != null && plant.notes!.isNotEmpty) {
      buf.writeln('Notes: ${plant.notes}');
    }
    if (logs.isNotEmpty) {
      buf.writeln('\nCare history (newest first):');
      for (final log in logs.take(20)) {
        final type = log.type == CareType.watering ? 'Watered' : 'Fertilised';
        buf.writeln('- ${_formatDate(log.date)}: $type'
            '${log.notes != null ? " — ${log.notes}" : ""}');
      }
    } else {
      buf.writeln('No care history logged yet.');
    }

    final prevHistLen = _gemini?.conversationHistory.length ?? 0;
    _gemini?.injectPlantContext(buf.toString());

    final contextMsg = _ChatMessage(
      text: 'Context added: ${plant.name}',
      isUser: false,
      isContext: true,
    );
    setState(() => _messages.add(contextMsg));
    _persistMessage(contextMsg);
    _persistNewHistoryTurns(prevHistLen);
    _scrollToBottom();
  }

  static String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Persistence helpers ───────────────────────────────────────────────────

  Future<void> _persistMessage(_ChatMessage msg) async {
    await _chatRepo?.insertMessage(PersistedMessage(
      text: msg.text,
      isUser: msg.isUser,
      isContext: msg.isContext,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _persistNewHistoryTurns(int prevLength) async {
    if (_chatRepo == null || _gemini == null) return;
    final history = _gemini!.conversationHistory;
    if (history.length <= prevLength) return;
    final newTurns = history.sublist(prevLength).cast<Map<String, dynamic>>();
    await _chatRepo!.appendGeminiTurns(newTurns);
  }

  // ── Function call handler ─────────────────────────────────────────────────

  Future<Map<String, dynamic>> _handleFunctionCall(
    String name,
    Map<String, dynamic> args,
  ) async {
    try {
      switch (name) {
        case 'add_plant':
          final repo = await PlantRepository.create();
          final plant = Plant(
            name: args['name'] as String,
            species: args['species'] as String,
            wateringIntervalDays: args['watering_interval_days'] as int,
            notes: args['notes'] as String?,
            plantKey: args['plant_key'] as String?,
          );
          final id = await repo.insert(plant);
          await NotificationService.scheduleWateringReminder(
            plant.copyWith(id: id),
            notifyHour: await _savedNotifyHour(),
          );
          await _reloadPlants();
          _showCollectionChip('Added ${plant.name}');
          return {'success': true, 'plant_id': id, 'name': plant.name};

        case 'update_plant':
          final repo = await PlantRepository.create();
          final plantId = args['plant_id'] as int;
          final existing = await repo.getById(plantId);
          if (existing == null) {
            return {'success': false, 'error': 'Plant not found'};
          }
          final updated = existing.copyWith(
            name: args['name'] as String?,
            species: args['species'] as String?,
            wateringIntervalDays: args['watering_interval_days'] as int?,
            notes: args['notes'] as String?,
          );
          await repo.update(updated);
          await NotificationService.scheduleWateringReminder(
            updated,
            notifyHour: await _savedNotifyHour(),
          );
          await _reloadPlants();
          _showCollectionChip('Updated ${updated.name}');
          return {'success': true, 'name': updated.name};

        case 'delete_plant':
          final plantId = args['plant_id'] as int;
          final repo = await PlantRepository.create();
          final logRepo = await CareLogRepository.create();
          final photoRepo = await PlantPhotoRepository.create();
          final plant = await repo.getById(plantId);
          await logRepo.deleteByPlantId(plantId);
          await photoRepo.deleteByPlantId(plantId);
          await repo.delete(plantId);
          await NotificationService.cancelReminder(plantId);
          await _reloadPlants();
          _showCollectionChip('Deleted ${plant?.name ?? 'plant'}');
          return {'success': true};

        case 'log_care':
          final plantId = args['plant_id'] as int;
          final type = (args['type'] as String).toLowerCase();
          final careType =
              type == 'watering' ? CareType.watering : CareType.fertilizing;
          final logRepo = await CareLogRepository.create();
          final plantRepo = await PlantRepository.create();
          await logRepo.insert(CareLog(
            plantId: plantId,
            type: careType,
            date: DateTime.now(),
          ));
          final plant = await plantRepo.getById(plantId);
          if (plant != null) {
            final updated = careType == CareType.watering
                ? plant.copyWith(lastWateredDate: DateTime.now())
                : plant.copyWith(lastFertilizedDate: DateTime.now());
            await plantRepo.update(updated);
            if (careType == CareType.watering) {
              await NotificationService.scheduleWateringReminder(
                updated,
                notifyHour: await _savedNotifyHour(),
              );
            }
          }
          await _reloadPlants();
          _showCollectionChip(
            type == 'watering'
                ? 'Logged watering for ${plant?.name ?? 'plant'}'
                : 'Logged fertilizing for ${plant?.name ?? 'plant'}',
          );
          return {'success': true};

        case 'add_photo':
          final bytes = _currentImageBytes;
          if (bytes == null) {
            return {
              'success': false,
              'error': 'No image in the current message to save.',
            };
          }
          final plantId = args['plant_id'] as int;
          final notes = args['notes'] as String?;
          final setAsCover = (args['set_as_cover'] as bool?) ?? false;

          final appDir = await getApplicationDocumentsDirectory();
          final photosDir =
              Directory(p.join(appDir.path, 'plant_photos'));
          if (!await photosDir.exists()) {
            await photosDir.create(recursive: true);
          }
          final fileName =
              '${plantId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final destPath = p.join(photosDir.path, fileName);
          await File(destPath).writeAsBytes(bytes);

          final photoRepo = await PlantPhotoRepository.create();
          final existing = await photoRepo.getByPlantId(plantId);
          final isFirst = existing.isEmpty;

          final photo = await photoRepo.insert(PlantPhoto(
            plantId: plantId,
            filePath: destPath,
            dateTaken: DateTime.now(),
            isCover: isFirst || setAsCover,
            notes: notes,
          ));
          if (!isFirst && setAsCover) {
            await photoRepo.setCover(plantId, photo.id!);
          }

          final plantRepo = await PlantRepository.create();
          final plant = await plantRepo.getById(plantId);
          _showCollectionChip('Photo saved to ${plant?.name ?? 'plant'}');
          return {'success': true, 'photo_id': photo.id};

        default:
          return {'success': false, 'error': 'Unknown function: $name'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> _reloadPlants() async {
    final repo = await PlantRepository.create();
    final photoRepo = await PlantPhotoRepository.create();
    final plants = await repo.getAll();
    final coverPhotos = await photoRepo.getCoverPhotoMap();
    if (!mounted) return;
    setState(() {
      _allPlants = plants;
      _coverPhotos = coverPhotos;
    });
  }

  Widget _plantIconFallback() => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.statusGreenBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.eco, size: 18, color: AppColors.forest),
      );

  Future<int> _savedNotifyHour() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('reminder_hour') ?? NotificationService.defaultNotifyHour;
  }

  void _showCollectionChip(String label) {
    if (!mounted) return;
    final msg = _ChatMessage(text: label, isUser: false, isContext: true);
    setState(() => _messages.add(msg));
    _persistMessage(msg);
    _scrollToBottom();
  }

  // ── Messaging ─────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    if (_gemini == null) return;
    final text = _textController.text.trim();
    if (text.isEmpty && _pendingImage == null) return;

    if (!_gemini!.isConfigured) {
      setState(() {
        _messages.add(const _ChatMessage(
          text:
              'No API key found. Run the app with:\n\nflutter run --dart-define=GEMINI_API_KEY=your_key_here\n\nGet a free key at aistudio.google.com',
          isUser: false,
        ));
      });
      return;
    }

    final imageBytes = _pendingImage;
    _currentImageBytes = imageBytes;
    final userMsg = _ChatMessage(
      text: text,
      isUser: true,
      imageBytes: imageBytes,
    );
    setState(() {
      _messages.add(userMsg);
      _pendingImage = null;
      _isStreaming = true;
    });
    _textController.clear();
    _persistMessage(userMsg);
    _scrollToBottom();

    setState(() => _messages.add(const _ChatMessage(text: '', isUser: false)));
    final aiIndex = _messages.length - 1;
    final prevHistLen = _gemini!.conversationHistory.length;

    try {
      final stream = _gemini!.sendMessageStream(
        text.isEmpty ? 'Please analyse this plant image.' : text,
        imageBytes: imageBytes,
        onFunctionCall: _handleFunctionCall,
      );
      await for (final chunk in stream) {
        if (!mounted) return;
        setState(() {
          _messages[aiIndex] =
              _messages[aiIndex].copyWith(text: _messages[aiIndex].text + chunk);
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages[aiIndex] = _ChatMessage(text: 'Error: $e', isUser: false);
      });
    }

    if (!mounted) return;
    setState(() => _isStreaming = false);
    _currentImageBytes = null;

    // Persist completed AI message and any new Gemini history turns.
    _persistMessage(_messages[aiIndex]);
    _persistNewHistoryTurns(prevHistLen);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showImagePicker() async {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.statusGreenBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: AppColors.forest),
                ),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.statusGreenBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: AppColors.forest),
                ),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1024,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _pendingImage = bytes);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          _buildHeader(context),
          _buildContextBar(),
          Expanded(child: _buildMessageList()),
          if (_pendingImage != null) _buildImagePreview(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildContextBar() {
    final hasPlants = _allPlants.isNotEmpty;
    return GestureDetector(
      onTap: hasPlants ? _showPlantPicker : null,
      child: Container(
        color: AppColors.cardBg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              _contextPlant != null ? Icons.eco : Icons.add_circle_outline,
              size: 15,
              color: _contextPlant != null
                  ? AppColors.forest
                  : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _contextPlant != null
                    ? 'Discussing: ${_contextPlant!.name}'
                    : hasPlants
                        ? 'Add plant context'
                        : 'No plants in collection yet',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _contextPlant != null
                      ? AppColors.forest
                      : AppColors.textMuted,
                ),
              ),
            ),
            if (hasPlants)
              Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: AppColors.darkOlive,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 4,
        right: 16,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.tan, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.forest,
              border: Border.all(
                  color: AppColors.tan.withValues(alpha: 0.3), width: 1.5),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _renameBotDialog,
              child: Row(
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _isLoading ? 'Loading...' : _botName,
                                style: const TextStyle(
                                  color: AppColors.tan,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.edit,
                              size: 12,
                              color: AppColors.tan.withValues(alpha: 0.6),
                            ),
                          ],
                        ),
                        Text(
                          _gemini == null
                              ? 'Connecting...'
                              : _gemini!.model,
                          style: TextStyle(
                            color: AppColors.tan.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        final isCurrentlyStreaming =
            _isStreaming && i == _messages.length - 1 && !msg.isUser;
        return _MessageBubble(
          message: msg,
          isStreaming: isCurrentlyStreaming,
        );
      },
    );
  }

  Widget _buildImagePreview() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              _pendingImage!,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Image ready to send',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.textMuted,
            onPressed: () => setState(() => _pendingImage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        children: [
          _IconBtn(
            icon: Icons.add_photo_alternate_outlined,
            onTap: _showImagePicker,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: _gemini != null,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: _gemini == null
                    ? 'Connecting to $_botName...'
                    : 'Ask about your plants…',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: AppColors.cardBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide:
                      const BorderSide(color: AppColors.forest, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(
            onTap: _isStreaming ? null : _sendMessage,
            active: !_isStreaming,
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final bool isStreaming;

  const _MessageBubble({required this.message, required this.isStreaming});

  @override
  Widget build(BuildContext context) {
    if (message.isContext) return _contextCard();
    if (message.isUser) return _userBubble();
    return _aiBubble();
  }

  Widget _contextCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.statusGreenBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.eco, size: 13, color: AppColors.forest),
              const SizedBox(width: 5),
              Text(
                message.text,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _userBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.darkOlive,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        message.imageBytes!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (message.text.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiBubble() {
    final isEmpty = message.text.isEmpty && !isStreaming;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.forest,
            ),
            child: const Icon(Icons.eco, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isEmpty
                  ? const _TypingDots()
                  : Text(
                      isStreaming ? '${message.text}▌' : message.text,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typing dots ───────────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _anims = _controllers
        .map((c) => Tween<double>(begin: 0, end: -7)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();

    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) _controllers[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => AnimatedBuilder(
            animation: _anims[i],
            builder: (_, _) => Transform.translate(
              offset: Offset(0, _anims[i].value),
              child: Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.textMuted.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _IconBtn({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.cardBg,
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool active;

  const _SendButton({required this.onTap, required this.active});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? AppColors.forest : AppColors.divider,
        ),
        child: const Icon(Icons.arrow_upward_rounded,
            color: Colors.white, size: 20),
      ),
    );
  }
}
