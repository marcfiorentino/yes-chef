# Yes Chef!
Turn the ingredients you have into recipes you can cook now, with macros and diet filters.

## Open and run in Xcode (iOS Simulator)
1. Open the project in Xcode:
   ```bash
   open YesChef.xcodeproj
   ```
2. In Xcode, select the **YesChef** scheme.
3. Choose an iOS 17+ simulator device (for example, **iPhone 15**).
4. Press **⌘R** (Run) to build and launch the app in the simulator.

### Notes
- `YesChef` is the iOS SwiftUI app target.
- `YesChefCore` is kept as a separate local Swift package module and is linked into the app target.


## Ingredient catalog data
- Source dataset: `Sources/YesChefCore/Resources/ingredient_catalog_source.json`
- Runtime SQLite DB: generated on first launch in the app's Application Support directory from the bundled JSON source.
- Optional prebuild/regeneration command for local verification:
  ```bash
  ./scripts/build_ingredient_catalog_db.py
  ```
