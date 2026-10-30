// Guards the prompt helpers the two-line and root prompts depend on.
import 'package:flutter_test/flutter_test.dart';
import 'package:g_launcher/features/terminal/ansi.dart';
import 'package:g_launcher/features/terminal/prompt.dart';

void main() {
  group('derivedRootPrompt', () {
    test('turns the trailing dollar into a hash, keeping its spacing', () {
      expect(derivedRootPrompt(r'{user}@{host}:{cwd}$ '),
          '\x1b[31m{user}@{host}:{cwd}# \x1b[0m');
    });

    test('a dollar that is not trailing is left alone', () {
      expect(derivedRootPrompt(r'$ {cwd} > '), '\x1b[31m\$ {cwd} > \x1b[0m');
    });
  });

  group('splitPrompt', () {
    test('a one-line prompt has nothing above', () {
      final cut = splitPrompt('~ > ');
      expect(cut.above, '');
      expect(cut.inline, '~ > ');
    });

    test('cuts at the LAST newline', () {
      final cut = splitPrompt('a\nb\n> ');
      expect(cut.above, 'a\nb');
      expect(cut.inline, '> ');
    });
  });

  group('carriedSgr', () {
    test('keeps only SGR sequences, in order', () {
      expect(carriedSgr('\x1b[32m┌──(\x1b[1;34mkali\x1b[0;32m)'),
          '\x1b[32m\x1b[1;34m\x1b[0;32m');
    });

    test('a colour opened above is still open on the inline part', () {
      const above = '\x1b[32m┌──(kali)';
      final line = (AnsiParser()..feed('${carriedSgr(above)}└─\$ ')).current;
      expect(line.text, '└─\$ ');
      expect(line.spans.first.style.fg, const AnsiIndexedColor(2));
    });
  });

  test('the Kali template renders to two lines with no stray braces', () {
    const kali = '\x1b[32m┌──(\x1b[1;34mkali㉿kali\x1b[0;32m)-[\x1b[0;1m{cwd}'
        '\x1b[0;32m]\n└─\x1b[1;34m\$\x1b[0m ';
    final cut = splitPrompt(renderPrompt(kali));
    final top = (AnsiParser()..feed('${cut.above}\n')).committed.single.text;
    expect(top, '┌──(kali㉿kali)-[~]');
    expect((AnsiParser()..feed(cut.inline)).current.text, '└─\$ ');
  });
}
