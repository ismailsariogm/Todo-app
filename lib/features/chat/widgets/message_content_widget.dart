import 'dart:convert';

import 'package:flutter/material.dart';

import 'chat_attach_sheet.dart';

/// Mesaj content'ini parse eder ve uygun widget döndürür.
/// [IMG], [DOC], [CONTACT], [POLL] prefix'lerini destekler.
Widget buildMessageContent(String content, {bool isMe = true}) {
  if (content.startsWith(kMsgPrefixImage)) {
    final base64 = content.substring(kMsgPrefixImage.length);
    return _ImageContent(base64: base64);
  }
  if (content.startsWith(kMsgPrefixDocument)) {
    final rest = content.substring(kMsgPrefixDocument.length);
    final pipe = rest.indexOf('|');
    if (pipe < 0) return _fallbackText(content);
    final name = rest.substring(0, pipe);
    return _DocumentContent(fileName: name);
  }
  if (content.startsWith(kMsgPrefixContact)) {
    try {
      final json = content.substring(kMsgPrefixContact.length);
      final map = jsonDecode(json) as Map<String, dynamic>;
      final displayName = map['displayName'] as String? ?? 'Bilinmeyen';
      return _ContactContent(displayName: displayName);
    } catch (_) {
      return _fallbackText(content);
    }
  }
  if (content.startsWith(kMsgPrefixPoll)) {
    try {
      final json = content.substring(kMsgPrefixPoll.length);
      final map = jsonDecode(json) as Map<String, dynamic>;
      final question = map['q'] as String? ?? 'Anket';
      final opts = (map['opts'] as List<dynamic>?)?.cast<String>() ?? [];
      return _PollContent(question: question, options: opts);
    } catch (_) {
      return _fallbackText(content);
    }
  }
  return _fallbackText(content);
}

Widget _fallbackText(String content) {
  return Text(
    content,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 14.5,
      height: 1.4,
    ),
  );
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.base64});
  final String base64;

  @override
  Widget build(BuildContext context) {
    try {
      final bytes = base64Decode(base64);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      );
    } catch (_) {
      return const Icon(Icons.broken_image_outlined,
          color: Colors.white54, size: 48);
    }
  }
}

class _DocumentContent extends StatelessWidget {
  const _DocumentContent({required this.fileName});
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file,
              color: Colors.white.withValues(alpha: 0.9), size: 28),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              fileName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactContent extends StatelessWidget {
  const _ContactContent({required this.displayName});
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person,
              color: Colors.white.withValues(alpha: 0.9), size: 24),
          const SizedBox(width: 10),
          Text(
            displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PollContent extends StatelessWidget {
  const _PollContent({
    required this.question,
    required this.options,
  });
  final String question;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.poll_outlined,
                  color: Colors.white.withValues(alpha: 0.9), size: 20),
              const SizedBox(width: 6),
              Text(
                question,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...options.map((o) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.radio_button_unchecked,
                        size: 16, color: Colors.white.withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Text(
                      o,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
