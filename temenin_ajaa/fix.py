import re

with open('c:/temenin_ajaa/temenin_ajaa/lib/modules/clients/booking/screens/client_waiting_countdown_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const SnackBar\(\s*content: Text\("Waktu tunggu telah habis\. Menunggu respons partner\.\.\."\),\s*backgroundColor: Colors\.orange,\s*duration: Duration\(seconds: 4\),\s*\),\s*\);',
    r'WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Waktu tunggu telah habis. Menunggu respons partner..."), backgroundColor: Colors.orange, duration: Duration(seconds: 4))); } });',
    content
)

content = re.sub(
    r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const SnackBar\(\s*content: Text\("[^"]+?Driver telah memulai perjalanan \(OTW\) menuju lokasi Anda!"\),\s*backgroundColor: Colors\.green,\s*\),\s*\);',
    r'WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("?? Driver telah memulai perjalanan (OTW) menuju lokasi Anda!"), backgroundColor: Colors.green,)); } });',
    content
)

content = re.sub(
    r'if \(mounted\) \{\s*ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*const SnackBar\(\s*content: Text\("[^"]+?PIN Berhasil Diverifikasi! Waktu tunggu berakhir, melanjutkan ke pelacakan\."\),\s*backgroundColor: Colors\.green,\s*\),\s*\);\s*_navigateToTracking',
    r'WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("? PIN Berhasil Diverifikasi! Waktu tunggu berakhir, melanjutkan ke pelacakan."), backgroundColor: Colors.green,)); _navigateToTracking',
    content
)

content = re.sub(
    r'// Background MAP \(Disabled functionality, just visual\).*?Container\(\s*color: Colors\.black\.withOpacity\(0\.6\),\s*\),',
    r'// Background MAP (Disabled functionality, just visual)\n          Container(color: AppTheme.background),',
    content,
    flags=re.DOTALL
)

with open('c:/temenin_ajaa/temenin_ajaa/lib/modules/clients/booking/screens/client_waiting_countdown_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
