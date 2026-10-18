# Current compatibility contract

Version: 0.19.1

Earthworks Mod ID is B47ANCEDEarthworks, with no required external Mod IDs. The retained import/global/save/sandbox namespace is groundWorks. CAT integration and its CAT-only Knowledge & Wisdom dependency are removed at the user's request. No external source/assets are bundled or redistributed; CAT repository onboarding is canceled.

Consumer API advances from 2 to 3: built-in vehicle kind/provider mappings return nil; old VehicleManuals.ensure returns false without reading cargo or changing issuance markers. No automatic machine provider or validator fallback remains. A generic trusted provider must explicitly register its authority validator. Machine spoil exchange is rejected. Existing machine-only road metadata remains readable but is not silently converted to a manual project; no unavailable manual concrete-road start is shown.

Keep existing saved terrain, job/route schema IDs and historical issuance/qualification data untouched. Dropping an integration does not erase saved markers or manufacture replacement items. Knowledge & Wisdom retains old saved item declarations/aliases inertly in its independent project; standalone Earthworks does not load it or depend on its private backend.

The minimal dedicated baseline enables only Earthworks. Optional weatherWorks precipitation and itjustWorks heavy-object contracts remain as previously implemented, outside this baseline's compatibility proof. Their presence is not inferred from directories or Workshop subscriptions. Dedicated G7 and stable G8 remain blocked until actual runtime coverage; no SP prerequisite.
