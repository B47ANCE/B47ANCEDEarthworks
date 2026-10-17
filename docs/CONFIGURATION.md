# Sandbox configuration

Version: 0.18.0

The server's sandbox configuration is authoritative for shared gameplay. Option identifiers/defaults are preserved across the rename; names/tooltips live in the source English Sandbox.json. Only English fallback is supplied; folder counts do not prove localization or native loading.

| Stable identifier | Type / bounds | Default | Purpose |
| --- | --- | --- | --- |
| `groundWorks.EnableAnimalTraffic` | boolean | true | Animal wear observer |
| `groundWorks.EnablePlayerFootTraffic` | boolean | true | Player footpath wear |
| `groundWorks.EnableVehicleTraffic` | boolean | true | Installed-wheel vehicle wear |
| `groundWorks.EnableUnoccupiedVehicleTraffic` | boolean | true | Loaded unoccupied-vehicle wear |
| `groundWorks.WearRecoveryPerDay` | double 0..10 | 0.05 | Daily wear recovery; zero disables recovery |
| `groundWorks.EnableLiveOpenPit` | boolean | false | Explicit debug/admin instant-volume convenience |
| `groundWorks.EnableHandExcavation` | boolean | true | Hand-tool excavation |
| `groundWorks.EnableCollapse` | boolean | true | Unsecured loaded excavation collapse |
| `groundWorks.CollapseKills` | boolean | true | Fatal collapse; false uses existing evacuation handling |
| `groundWorks.CollapseChancePerHour` | double 0..1 | 0.01 | Chance per hour per depth; zero disables random collapse |

Existing saves retain these identifiers and source defaults. The retired enhanced-visibility option is not registered or consumed; an old stored value has no effect. Rendering is fixed to vanilla, so no replacement cosmetic toggle is exposed. CAT owns its separate RequireOperatorManuals option; it applies only when both frameworks are enabled and never bypasses Knowledge & Wisdom's MP guard.

Technical caps/queue limits and protocol IDs are implementation safety bounds, not new gameplay options. Actual engine sandbox serialization, old-save loading and dedicated behavior remain NOT TESTED for this version.
