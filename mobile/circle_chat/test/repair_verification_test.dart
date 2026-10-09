import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:circle_chat/core/models/models.dart';
import 'package:circle_chat/core/theme/app_theme.dart';
import 'package:circle_chat/core/widgets/avatar_widget.dart';

void main() {
  group('Comprehensive Repair - Model Deserialization Tests', () {
    test('MessageModel deserializes PascalCase, camelCase, and handles int/string conversions safely', () {
      final pascalCaseJson = {
        'Id': 'msg-123',
        'ConversationId': 'conv-456',
        'SenderId': 'user-789',
        'SenderDisplayName': 'Alice',
        'SenderProfileImageUrl': '/uploads/avatars/alice.png',
        'Content': 'Hello world',
        'MessageType': '1', // string format representation
        'DeliveryStatus': 2,
        'CreatedAt': '2026-10-09T20:00:00Z',
        'UpdatedAt': null,
        'IsDeleted': false,
        'Reactions': [],
        'Attachments': [
          {
            'Id': 'att-1',
            'FileName': 'photo.jpg',
            'ContentType': 'image/jpeg',
            'FileSizeBytes': 1024,
            'DownloadUrl': '/uploads/media/photo.jpg',
            'ThumbnailUrl': null,
          }
        ],
      };

      final msg = MessageModel.fromJson(pascalCaseJson);
      expect(msg.id, 'msg-123');
      expect(msg.conversationId, 'conv-456');
      expect(msg.senderId, 'user-789');
      expect(msg.senderDisplayName, 'Alice');
      expect(msg.content, 'Hello world');
      expect(msg.messageType, 1);
      expect(msg.deliveryStatus, 2);
      expect(msg.attachments.length, 1);
      expect(msg.attachments.first.downloadUrl, '/uploads/media/photo.jpg');
    });

    test('ConversationModel safely parses payload with null or nested lastMessage', () {
      final json = {
        'id': 'c-1',
        'type': 1,
        'name': 'Direct Chat',
        'unreadCount': 0,
        'lastMessage': {
          'id': 'm-99',
          'conversationId': 'c-1',
          'senderId': 'u-2',
          'senderDisplayName': 'Bob',
          'content': 'Hey!',
          'createdAt': '2026-10-09T20:05:00Z',
        },
        'members': [
          {'userId': 'u-1', 'displayName': 'Me'},
          {'userId': 'u-2', 'displayName': 'Bob'}
        ]
      };

      final conv = ConversationModel.fromJson(json);
      expect(conv.id, 'c-1');
      expect(conv.name, 'Direct Chat');
      expect(conv.lastMessage, isNotNull);
      expect(conv.lastMessage!.content, 'Hey!');
      expect(conv.members.length, 2);
    });
  });

  group('Comprehensive Repair - AppTheme Verification', () {
    test('Light and Dark themes are distinct and use high-contrast cozy palette', () {
      final dark = AppTheme.darkTheme;
      final light = AppTheme.lightTheme;

      // Verify scaffolds are distinct
      expect(dark.scaffoldBackgroundColor, isNot(equals(light.scaffoldBackgroundColor)));

      // Verify dark uses deep navy/slate #101820
      expect(dark.scaffoldBackgroundColor, AppTheme.darkScaffold);
      expect(dark.colorScheme.surface, AppTheme.darkSurface);
      expect(dark.colorScheme.primary, AppTheme.primaryDark);

      // Verify light uses soft warm off-white #F7F9FB
      expect(light.scaffoldBackgroundColor, AppTheme.lightScaffold);
      expect(light.colorScheme.surface, AppTheme.lightSurface);
      expect(light.colorScheme.primary, AppTheme.lightAccent);

      // Verify theme modes
      expect(dark.brightness, Brightness.dark);
      expect(light.brightness, Brightness.light);
    });
  });

  group('Comprehensive Repair - Avatar URL & Initials Resolution', () {
    test('resolveMediaUrl normalizes relative paths and localhost', () {
      expect(resolveMediaUrl(''), isNull);
      expect(resolveMediaUrl(null), isNull);
      expect(
        resolveMediaUrl('https://example.com/pic.jpg'),
        'https://example.com/pic.jpg',
      );
      // Relative path resolution
      final resolved = resolveMediaUrl('/api/media/pic.jpg');
      expect(resolved, contains('/api/media/pic.jpg'));
      expect(resolved, startsWith('http'));

      // Localhost replacement for Android emulators/devices
      final localResolved = resolveMediaUrl('http://localhost:5000/api/media/pic.jpg');
      expect(localResolved, isNot(contains('localhost')));
    });

    test('getInitials generates concise initials', () {
      expect(getInitials('John Doe'), 'JD');
      expect(getInitials('Alice'), 'A');
      expect(getInitials('  Bob   Smith  '), 'BS');
      expect(getInitials(''), 'C');
    });
  });
}
