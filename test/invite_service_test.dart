import 'package:flutter_test/flutter_test.dart';
import 'package:fourcus/services/invite_service.dart';

void main() {
  group('InviteService', () {
    test('generateInviteCode returns 6 unambiguous chars', () {
      final code = InviteService.generateInviteCode();
      expect(code.length, 6);
      expect(InviteService.isValidCodeFormat(code), isTrue);
      // No ambiguous characters: 0/O, 1/I/L are excluded.
      expect(code.contains(RegExp(r'[01OIL]')), isFalse);
    });

    test('generated codes are unique', () {
      final codes =
          List.generate(200, (_) => InviteService.generateInviteCode());
      expect(codes.toSet().length, 200);
    });

    test('parseInviteCode extracts code from share text', () {
      const text = 'Join my 4cus accountability group "Runners"! '
          'Open 4cus, tap Join with code, and enter: AB3DX9';
      expect(InviteService.parseInviteCode(text), 'AB3DX9');
    });

    test('parseInviteCode returns null when absent', () {
      expect(InviteService.parseInviteCode('hello world'), isNull);
    });

    test('isValidCodeFormat rejects bad input', () {
      expect(InviteService.isValidCodeFormat('ABC12'), isFalse);
      expect(InviteService.isValidCodeFormat('ABC1234'), isFalse);
      expect(InviteService.isValidCodeFormat('ABO123'), isFalse); // O excluded
      expect(InviteService.isValidCodeFormat('ab3dx9'), isTrue); // case-insens
    });
  });
}
