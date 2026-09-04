# Project Structure

- 📁 **booking**
- 📁 **core**
  - 📁 **constants**
    - 📄 `core\constants\api_constants.dart`
    - 📄 `core\constants\app_constants.dart`
  - 📁 **services**
    - 📄 `core\services\auth_service.dart`
        <details>
          <summary>Imports</summary>

          - `../../data/models/user_model.dart`
          - `../constants/api_constants.dart`
          - `dart:convert`
          - `package:flutter/foundation.dart`
          - `package:http/http.dart`
          - `package:shared_preferences/shared_preferences.dart`
        </details>

  - 📁 **theme**
    - 📄 `core\theme\app_theme.dart`
        <details>
          <summary>Imports</summary>

          - `package:flutter/material.dart`
        </details>

- 📁 **data**
  - 📁 **models**
    - 📄 `data\models\user_model.dart`
- 📄 `main.dart`
    <details>
      <summary>Imports</summary>

      - `modules/home/screens/home_screen.dart`
      - `package:flutter/material.dart`
      - `package:provider/provider.dart`
      - `package:supabase_flutter/supabase_flutter.dart`
      - `package:temenin_ajaa/modules/auth/onboarding/onboarding_screen.dart`
      - `package:temenin_ajaa/modules/home/screens/home_screen.dart`
      - `providers/auth_provider.dart`
    </details>

- 📁 **modules**
  - 📁 **auth**
    - 📁 **onboarding**
      - 📄 `modules\auth\onboarding\onboarding_screen.dart`
          <details>
            <summary>Imports</summary>

            - `../../home/screens/home_screen.dart`
            - `dart:ui`
            - `package:flutter/material.dart`
            - `package:shared_preferences/shared_preferences.dart`
          </details>

      - 📁 **screens**
        - 📄 `modules\auth\onboarding\screens\onboarding_screen.dart`
    - 📁 **screens**
      - 📄 `modules\auth\screens\login_screen.dart`
          <details>
            <summary>Imports</summary>

            - `../../../providers/auth_provider.dart`
            - `../../home/screens/home_screen.dart`
            - `package:flutter/material.dart`
            - `package:google_fonts/google_fonts.dart`
            - `package:provider/provider.dart`
            - `register_screen.dart`
          </details>

      - 📄 `modules\auth\screens\register_screen.dart`
          <details>
            <summary>Imports</summary>

            - `../../../providers/auth_provider.dart`
            - `../../home/screens/home_screen.dart`
            - `package:flutter/material.dart`
            - `package:google_fonts/google_fonts.dart`
            - `package:provider/provider.dart`
          </details>

      - 📄 `modules\auth\screens\splash_screen.dart`
          <details>
            <summary>Imports</summary>

            - `../../../../core/constants/app_constants.dart`
            - `../../../../core/theme/app_theme.dart`
            - `../widgets/splash_animated_background.dart`
            - `package:flutter/material.dart`
            - `package:go_router/go_router.dart`
            - `package:temenin_ajaa/routes/app_routes.dart`
          </details>

    - 📁 **widgets**
      - 📄 `modules\auth\widgets\login_background.dart`
          <details>
            <summary>Imports</summary>

            - `../../../../core/theme/app_theme.dart`
            - `package:flutter/material.dart`
          </details>

      - 📄 `modules\auth\widgets\login_footer.dart`
          <details>
            <summary>Imports</summary>

            - `../../../../core/theme/app_theme.dart`
            - `package:flutter/material.dart`
          </details>

      - 📄 `modules\auth\widgets\login_form.dart`
          <details>
            <summary>Imports</summary>

            - `../../../../core/theme/app_theme.dart`
            - `dart:ui`
            - `package:flutter/material.dart`
            - `package:go_router/go_router.dart`
            - `package:temenin_ajaa/routes/app_routes.dart`
          </details>

      - 📄 `modules\auth\widgets\splash_animated_background.dart`
          <details>
            <summary>Imports</summary>

            - `../../../../core/theme/app_theme.dart`
            - `package:flutter/material.dart`
          </details>

  - 📁 **home**
    - 📁 **screens**
      - 📄 `modules\home\screens\home_loggedin_screen.dart`
          <details>
            <summary>Imports</summary>

            - `dart:ui`
            - `package:flutter/material.dart`
            - `package:flutter_animate/flutter_animate.dart`
            - `package:google_fonts/google_fonts.dart`
            - `package:provider/provider.dart`
          </details>

      - 📄 `modules\home\screens\home_screen.dart`
          <details>
            <summary>Imports</summary>

            - `../../../providers/auth_provider.dart`
            - `../../auth/screens/login_screen.dart`
            - `dart:ui`
            - `package:flutter/material.dart`
            - `package:flutter_animate/flutter_animate.dart`
            - `package:google_fonts/google_fonts.dart`
            - `package:provider/provider.dart`
          </details>

    - 📁 **widgets**
      - 📄 `modules\home\widgets\bottom_nav_bar.dart`
          <details>
            <summary>Imports</summary>

            - `../../../core/theme/app_theme.dart`
            - `package:flutter/material.dart`
          </details>

      - 📄 `modules\home\widgets\profile_tab.dart`
          <details>
            <summary>Imports</summary>

            - `../../../providers/auth_provider.dart`
            - `package:flutter/material.dart`
            - `package:google_fonts/google_fonts.dart`
            - `package:provider/provider.dart`
          </details>

- 📁 **payment**
- 📁 **profile**
- 📁 **providers**
  - 📄 `providers\auth_provider.dart`
      <details>
        <summary>Imports</summary>

        - `../data/models/user_model.dart`
        - `package:flutter/material.dart`
        - `package:temenin_ajaa/core/services/auth_service.dart`
      </details>

- 📁 **routes**
  - 📄 `routes\app_routes.dart`
      <details>
        <summary>Imports</summary>

        - `../modules/auth/screens/login_screen.dart`
        - `../modules/auth/screens/splash_screen.dart`
        - `package:flutter/material.dart`
      </details>

- 📁 **services**
- 📁 **supabase**

## Project Type

- **Project Type:** monorepo
- **Indicators:**
  - Found 18 pubspec.yaml files (monorepo indicator)
  - Found `flutter` key in pubspec.yaml


## Detected Frameworks

| Framework | In pubspec | Files using it |
|-----------|-----------|----------------|
| GoRouter | Yes | 2 |
| Provider | Yes | 7 |


## Architecture

### Detected Layers

- **Screen** (6 files)
- **Widget** (6 files)
- **Service** (1 file)
- **Model** (1 file)
- **Provider** (1 file)

### Entry Points

- `lib\lib\main.dart`

### Layer Dependencies

- Provider → Data
- Screen → Core, Provider, Widget
- Service → Data
- Widget → Core, Provider



## Project Statistics

- Total Files: 21
- Dart Files: 21
- Total Lines of Dart Code: 4503
- Largest File: `lib\screens\home_screen.dart` with 844 lines
- Smallest File: `lib\screens\onboarding_screen.dart` with 2 lines


## TODO and FIXME Comments

File: lib\onboarding\onboarding_screen.dart
  - Line 226: // TODO: Navigasi ke login screen

File: lib\screens\onboarding_screen.dart
  - Line 2: // TODO Implement this library.



## Dependency Analysis

Package: flutter
Used in:
  - lib\services\auth_service.dart
  - lib\theme\app_theme.dart
  - lib\lib\main.dart
  - lib\onboarding\onboarding_screen.dart
  - lib\screens\login_screen.dart
  - lib\screens\register_screen.dart
  - lib\screens\splash_screen.dart
  - lib\widgets\login_background.dart
  - lib\widgets\login_footer.dart
  - lib\widgets\login_form.dart
  - lib\widgets\splash_animated_background.dart
  - lib\screens\home_loggedin_screen.dart
  - lib\screens\home_screen.dart
  - lib\widgets\bottom_nav_bar.dart
  - lib\widgets\profile_tab.dart
  - lib\providers\auth_provider.dart
  - lib\routes\app_routes.dart

Package: http
Used in:
  - lib\services\auth_service.dart

Package: shared_preferences
Used in:
  - lib\services\auth_service.dart
  - lib\onboarding\onboarding_screen.dart

Package: provider
Used in:
  - lib\lib\main.dart
  - lib\screens\login_screen.dart
  - lib\screens\register_screen.dart
  - lib\screens\home_loggedin_screen.dart
  - lib\screens\home_screen.dart
  - lib\widgets\profile_tab.dart

Package: supabase_flutter
Used in:
  - lib\lib\main.dart

Package: temenin_ajaa
Used in:
  - lib\lib\main.dart
  - lib\screens\splash_screen.dart
  - lib\widgets\login_form.dart
  - lib\providers\auth_provider.dart

Package: google_fonts
Used in:
  - lib\screens\login_screen.dart
  - lib\screens\register_screen.dart
  - lib\screens\home_loggedin_screen.dart
  - lib\screens\home_screen.dart
  - lib\widgets\profile_tab.dart

Package: go_router
Used in:
  - lib\screens\splash_screen.dart
  - lib\widgets\login_form.dart

Package: flutter_animate
Used in:
  - lib\screens\home_loggedin_screen.dart
  - lib\screens\home_screen.dart



## Code Metrics

File: lib\constants\api_constants.dart
  Lines of Code: 84
  Classes: 1
  Methods: 2
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\constants\app_constants.dart
  Lines of Code: 18
  Classes: 1
  Methods: 0
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\services\auth_service.dart
  Lines of Code: 614
  Classes: 2
  Methods: 18
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\theme\app_theme.dart
  Lines of Code: 105
  Classes: 1
  Methods: 1
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\models\user_model.dart
  Lines of Code: 48
  Classes: 1
  Methods: 1
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\lib\main.dart
  Lines of Code: 87
  Classes: 2
  Methods: 2
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\onboarding\onboarding_screen.dart
  Lines of Code: 302
  Classes: 2
  Methods: 3
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\screens\onboarding_screen.dart
  Lines of Code: 2
  Classes: 0
  Methods: 0
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\screens\login_screen.dart
  Lines of Code: 361
  Classes: 2
  Methods: 9
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\screens\register_screen.dart
  Lines of Code: 488
  Classes: 2
  Methods: 6
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\screens\splash_screen.dart
  Lines of Code: 170
  Classes: 2
  Methods: 8
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\widgets\login_background.dart
  Lines of Code: 58
  Classes: 1
  Methods: 1
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\widgets\login_footer.dart
  Lines of Code: 62
  Classes: 1
  Methods: 1
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\widgets\login_form.dart
  Lines of Code: 319
  Classes: 2
  Methods: 11
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\widgets\splash_animated_background.dart
  Lines of Code: 44
  Classes: 1
  Methods: 1
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\screens\home_loggedin_screen.dart
  Lines of Code: 416
  Classes: 2
  Methods: 11
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\screens\home_screen.dart
  Lines of Code: 844
  Classes: 2
  Methods: 12
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\widgets\bottom_nav_bar.dart
  Lines of Code: 44
  Classes: 1
  Methods: 1
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\widgets\profile_tab.dart
  Lines of Code: 286
  Classes: 1
  Methods: 5
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\providers\auth_provider.dart
  Lines of Code: 134
  Classes: 1
  Methods: 8
  Comment Lines: 0
  Comment Ratio: 0.00%

File: lib\routes\app_routes.dart
  Lines of Code: 17
  Classes: 1
  Methods: 1
  Comment Lines: 0
  Comment Ratio: 0.00%



## Naming Conventions

- Files following suffix convention: 10/21 (47.6%)

### File Naming Conventions

| Suffix | Count |
|--------|-------|
| `_screen` | 7 |
| `_service` | 1 |
| `_model` | 1 |
| `_provider` | 1 |

### Class Naming Conventions

| Suffix | Count |
|--------|-------|
| `State` | 7 |
| `Screen` | 6 |
| `Service` | 1 |
| `Model` | 1 |
| `Provider` | 1 |



## File Purposes

### Purpose Summary

| Purpose | Count |
|---------|-------|
| widget | 13 |
| other | 4 |
| service | 1 |
| model | 1 |
| screen | 1 |
| provider | 1 |

### File Details

- `lib\constants\api_constants.dart` → other
- `lib\constants\app_constants.dart` → other
- `lib\lib\main.dart` → widget
- `lib\models\user_model.dart` → model
- `lib\onboarding\onboarding_screen.dart` → widget
- `lib\providers\auth_provider.dart` → provider
- `lib\routes\app_routes.dart` → other
- `lib\screens\home_loggedin_screen.dart` → widget
- `lib\screens\home_screen.dart` → widget
- `lib\screens\login_screen.dart` → widget
- `lib\screens\onboarding_screen.dart` → screen
- `lib\screens\register_screen.dart` → widget
- `lib\screens\splash_screen.dart` → widget
- `lib\services\auth_service.dart` → service
- `lib\theme\app_theme.dart` → other
- `lib\widgets\bottom_nav_bar.dart` → widget
- `lib\widgets\login_background.dart` → widget
- `lib\widgets\login_footer.dart` → widget
- `lib\widgets\login_form.dart` → widget
- `lib\widgets\profile_tab.dart` → widget
- `lib\widgets\splash_animated_background.dart` → widget



## Aggregated Metrics

- Total Classes: 29
- Total Methods: 102
- Average LOC per file: 214.4
- Average Comment Ratio: 0.0%
- Files without comments: 21

### Largest Files (Top 5)

1. `lib\screens\home_screen.dart` - 844 lines
2. `lib\services\auth_service.dart` - 614 lines
3. `lib\screens\register_screen.dart` - 488 lines
4. `lib\screens\home_loggedin_screen.dart` - 416 lines
5. `lib\screens\login_screen.dart` - 361 lines


