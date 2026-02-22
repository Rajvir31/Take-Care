# Take Care — Drink Pacing Coach — File Tree

```
TakeCareApp/
├── TakeCareApp.xcodeproj
├── PROJECT_STRUCTURE.md
│
├── Shared/
│   ├── Constants/
│   │   └── AppConstants.swift
│   ├── Models/
│   │   ├── DrinkLog.swift
│   │   ├── Session.swift
│   │   ├── DrinkTypeConfig.swift
│   │   ├── PacingEvent.swift
│   │   ├── UserSettings.swift
│   │   └── Schema.swift
│   ├── PacingEngine/
│   │   ├── RollingWindowHelpers.swift
│   │   ├── SensitivityPresets.swift
│   │   └── PacingEngine.swift
│   ├── Repositories/
│   │   ├── SessionRepository.swift
│   │   ├── DrinkLogRepository.swift
│   │   ├── PacingEventRepository.swift
│   │   ├── UserSettingsRepository.swift
│   │   └── DrinkTypeConfigRepository.swift
│   ├── Sync/
│   │   └── WatchConnectivityManager.swift
│   └── Utilities/
│       └── (DateHelpers, ExportEncoding — later)
│
├── WatchApp/
│   ├── ViewModels/
│   │   └── WatchSessionViewModel.swift
│   ├── Views/
│   │   └── WatchMainView.swift
│   └── Haptics/
│       └── WatchHaptics.swift
│
├── TakeCareWatchApp/
│   └── TakeCareWatchApp.swift   # @main, modelContainer
│
├── iPhoneApp/
│   ├── Views/
│   │   └── MainTabView.swift
│   ├── ViewModels/
│   │   ├── TonightViewModel.swift
│   │   ├── HistoryViewModel.swift
│   │   └── InsightsViewModel.swift
│   └── Features/
│       ├── Tonight/
│       │   └── TonightView.swift
│       ├── History/
│       │   ├── HistoryView.swift
│       │   └── SessionDetailView.swift
│       ├── Insights/
│       │   └── InsightsView.swift
│       └── Settings/
│           └── SettingsView.swift
│
└── Tests/
    ├── README.md
    └── TakeCareAppTests/
        ├── PacingEngineTests.swift
        ├── SessionRepositoryTests.swift
        └── SyncPayloadsTests.swift
```

**Target membership (conceptual):**
- **TakeCareApp (iOS):** Shared/*, iPhoneApp/*
- **TakeCareWatchApp (watchOS):** Shared/*, WatchApp/*, TakeCareWatchApp/*
