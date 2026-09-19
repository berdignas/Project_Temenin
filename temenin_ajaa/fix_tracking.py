import re

with open('c:/temenin_ajaa/temenin_ajaa/lib/modules/clients/booking/screens/tracking_driver_screen.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix 1: Ensure _ensureRealOtpExists() runs on any booking detail update
content = content.replace(
    "setState(() {\n      _bookingDetails = data;\n      _simulationState = status;",
    "setState(() {\n      _bookingDetails = data;\n      _simulationState = status;\n      _ensureRealOtpExists();"
)

# Fix 2: Include 'ongoing' in isOngoingSession check
old_is_ongoing = "final isOngoingSession = (_simulationState == 'started' || _simulationState == 'completion_requested') ||\n                             (addSub == 'started' || addSub == 'completion_requested');"
new_is_ongoing = "final isOngoingSession = (_simulationState == 'started' || _simulationState == 'ongoing' || _simulationState == 'completion_requested') ||\n                             (addSub == 'started' || addSub == 'ongoing' || addSub == 'completion_requested');"
content = content.replace(old_is_ongoing, new_is_ongoing)

with open('c:/temenin_ajaa/temenin_ajaa/lib/modules/clients/booking/screens/tracking_driver_screen.dart', 'w', encoding='utf-8') as f:
    f.write(content)
