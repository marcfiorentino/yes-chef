#if canImport(SwiftUI)
import SwiftUI
import AVFoundation
import Speech
import UIKit
import YesChefCore

@main
struct YesChefApp: App {
    @StateObject private var appModel = YesChefAppModel()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appModel)
        }
    }
}

@MainActor
final class YesChefAppModel: ObservableObject {
    enum Tab: Hashable {
        case pantry
        case recipes
        case shop
        case profile
    }

    @Published var pantry = PantryViewModel()
    @Published var recipesVM = RecipesViewModel()
    @Published var shop = ShopViewModel()
    @Published var selectedTab: Tab = .pantry
    @Published var hasOnboarded = false {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: Self.hasOnboardedKey) }
    }
    @Published var cookedEvents: [CookedEvent] = [] {
        didSet { save(cookedEvents, key: Self.cookedEventsKey) }
    }
    @Published var userPrefs = UserPrefs() {
        didSet {
            save(userPrefs, key: Self.prefsKey)
            refreshMatches()
        }
    }

    private static let pantryKey = "yeschef.pantry"
    private static let shopKey = "yeschef.shop"
    private static let prefsKey = "yeschef.prefs"
    private static let cookedEventsKey = "yeschef.cookedEvents"
    private static let hasOnboardedKey = "yeschef.hasOnboarded"

    init() {
        if let loadedRecipes = try? RecipeLoader.loadSeededRecipes() {
            recipesVM.reloadRecipes(loadedRecipes)
        }

        if let storedPantry: [PantryItem] = load(key: Self.pantryKey) {
            pantry.replaceItems(storedPantry)
        }

        if let storedShop: [RecipeIngredient] = load(key: Self.shopKey) {
            shop.replaceItems(storedShop)
        }

        if let storedPrefs: UserPrefs = load(key: Self.prefsKey) {
            userPrefs = storedPrefs
        }

        if let storedEvents: [CookedEvent] = load(key: Self.cookedEventsKey) {
            cookedEvents = storedEvents
        }

        hasOnboarded = UserDefaults.standard.bool(forKey: Self.hasOnboardedKey)
        refreshMatches()
    }

    func addPantryItem(name: String, quantity: String) {
        pantry.updateEntryText(name)
        guard pantry.confirmSave(quantity: quantity).isSome else { return }
        save(pantry.pantryItems, key: Self.pantryKey)
        refreshMatches()
        objectWillChange.send()
    }

    func addDetectedPantryEntries(_ entries: [DetectedPantryEntry], source: PantryEntrySource, rawInput: String? = nil) {
        guard !entries.isEmpty else { return }
        _ = pantry.addDetectedEntries(entries, source: source, rawInput: rawInput)
        save(pantry.pantryItems, key: Self.pantryKey)
        refreshMatches()
        objectWillChange.send()
    }

    func removePantryItems(at offsets: IndexSet) {
        pantry.removeItems(at: offsets)
        save(pantry.pantryItems, key: Self.pantryKey)
        refreshMatches()
        objectWillChange.send()
    }

    func addMissingToShop(_ ingredients: [RecipeIngredient]) {
        shop.addMissing(ingredients)
        save(shop.shoppingList, key: Self.shopKey)
        objectWillChange.send()
    }

    func addMissingFromAlmostThereRecipes() {
        let ingredients = recipesVM.state.almostThere.flatMap(\.missingIngredients)
        addMissingToShop(ingredients)
    }

    func addUnlockIngredientToShop(_ ingredientName: String) {
        shop.addIngredient(name: ingredientName)
        save(shop.shoppingList, key: Self.shopKey)
        objectWillChange.send()
    }

    func refreshMatches() {
        recipesVM.updateMatches(pantryItems: pantry.pantryItems, prefs: userPrefs)
        objectWillChange.send()
    }

    func completeOnboarding() {
        hasOnboarded = true
        selectedTab = .pantry
    }

    func resetOnboarding() {
        hasOnboarded = false
    }

    func logCooked(recipeID: UUID, servings: Int) {
        cookedEvents.insert(CookedEvent(recipeID: recipeID, servings: servings), at: 0)
    }

    var unlockSuggestions: [UnlockSuggestion] {
        recipesVM.unlockSuggestions(pantryItems: pantry.pantryItems, prefs: userPrefs)
    }

    var shareableShoppingList: String {
        let lines = shop.shoppingList.map { "• \($0.ingredientName) – \($0.quantity)" }
        return (["YesChef Shopping List", ""] + lines).joined(separator: "\n")
    }

    private func save<T: Codable>(_ value: T, key: String) {
        if let encoded = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    private func load<T: Codable>(key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

private extension Optional {
    var isSome: Bool { self != nil }
}

struct RootTabView: View {
    @EnvironmentObject private var appModel: YesChefAppModel

    var body: some View {
        TabView(selection: $appModel.selectedTab) {
            PantryTabView()
                .tabItem { Label("Pantry", systemImage: "cabinet") }
                .tag(YesChefAppModel.Tab.pantry)

            RecipesTabView()
                .tabItem { Label("Recipes", systemImage: "fork.knife") }
                .tag(YesChefAppModel.Tab.recipes)

            ShopTabView()
                .tabItem { Label("Shop", systemImage: "cart") }
                .tag(YesChefAppModel.Tab.shop)

            ProfileTabView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(YesChefAppModel.Tab.profile)
        }
        .tint(.orange)
        .fullScreenCover(isPresented: Binding(get: { !appModel.hasOnboarded }, set: { _ in })) {
            OnboardingFlowView()
                .environmentObject(appModel)
        }
    }
}

struct OnboardingFlowView: View {
    @EnvironmentObject private var appModel: YesChefAppModel
    @State private var step = 0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                Text("Welcome to YesChef")
                    .font(.largeTitle.bold())
                Text("Step \(step + 1) of 4")
                    .foregroundStyle(.secondary)

                Group {
                    switch step {
                    case 0:
                        optionSection(title: "Choose diet template(s)", options: DietTag.allCases, selection: $appModel.userPrefs.enabledDiets)
                    case 1:
                        optionSection(title: "Allergens (optional)", options: Allergen.allCases, selection: $appModel.userPrefs.allergens)
                    case 2:
                        macroInputs
                    default:
                        VStack(alignment: .leading, spacing: 8) {
                            Text("You're all set!")
                                .font(.title3.bold())
                            Text("Finish onboarding to start planning from your pantry.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                HStack {
                    if step > 0 {
                        Button("Back") { step -= 1 }
                    }
                    Spacer()
                    Button(step == 3 ? "Finish" : "Next") {
                        if step == 3 {
                            appModel.completeOnboarding()
                        } else {
                            step += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    private var macroInputs: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macro targets (optional)")
                .font(.headline)
            MacroTargetField(title: "Calories", suffix: "cal", value: Binding(
                get: { appModel.userPrefs.targetCalories },
                set: { appModel.userPrefs.targetCalories = $0 }
            ))
            MacroTargetField(title: "Protein", value: Binding(
                get: { appModel.userPrefs.targetProtein },
                set: { appModel.userPrefs.targetProtein = $0 }
            ))
            MacroTargetField(title: "Carbs", value: Binding(
                get: { appModel.userPrefs.targetCarbs },
                set: { appModel.userPrefs.targetCarbs = $0 }
            ))
            MacroTargetField(title: "Fat", value: Binding(
                get: { appModel.userPrefs.targetFat },
                set: { appModel.userPrefs.targetFat = $0 }
            ))
        }
    }

    private func optionSection<T: RawRepresentable & Hashable>(title: String, options: [T], selection: Binding<Set<T>>) -> some View where T.RawValue == String {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)]) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection.wrappedValue.contains(option)
                    Button(option.rawValue) {
                        if isSelected {
                            selection.wrappedValue.remove(option)
                        } else {
                            selection.wrappedValue.insert(option)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(isSelected ? .orange : .gray)
                }
            }
        }
    }
}

struct PantryTabView: View {
    enum EntryMode: String, CaseIterable, Identifiable {
        case type = "Type"
        case speak = "Speak"
        case scan = "Scan"

        var id: String { rawValue }
    }

    @EnvironmentObject private var appModel: YesChefAppModel
    @FocusState private var isIngredientInputFocused: Bool
    @State private var typedIngredient = ""
    @State private var quantity = ""
    @State private var mode: EntryMode = .type
    @State private var reviewEntries: [DetectedPantryEntry] = []
    @State private var reviewSource: PantryEntrySource = .spoken
    @State private var reviewRawInput: String?
    @StateObject private var speechVM = SpeechCaptureViewModel()
    @StateObject private var scannerVM = BarcodeScannerViewModel()

    private let staples = ["Eggs", "Milk", "Chicken", "Rice", "Garlic", "Onion", "Olive Oil", "Salt", "Pepper"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Entry Mode", selection: $mode) {
                        ForEach(EntryMode.allCases) { entryMode in
                            Text(entryMode.rawValue).tag(entryMode)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch mode {
                    case .type:
                        typedEntryContent
                    case .speak:
                        speakEntryContent
                    case .scan:
                        scanEntryContent
                    }
                } header: {
                    Text("Add Ingredient")
                }

                Section("In Your Pantry") {
                    if appModel.pantry.pantryItems.isEmpty {
                        VStack(spacing: 12) {
                            Text("Your pantry is empty.")
                                .font(.headline)
                            Text("Add ingredients to unlock recipe matches.")
                                .foregroundStyle(.secondary)
                            Button("Add ingredients") {
                                mode = .type
                                isIngredientInputFocused = true
                            }
                            .buttonStyle(.borderedProminent)
                            .font(.title3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(appModel.pantry.pantryItems) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.ingredientName)
                                        .font(.headline)
                                    HStack {
                                        if item.quantity != "—" {
                                            Text(item.quantity)
                                        }
                                        if item.source != .typed {
                                            Text(item.source == .spoken ? "Speak" : "Scan")
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: appModel.removePantryItems)
                    }
                }
            }
            .navigationTitle("Pantry")
            .listStyle(.insetGrouped)
            .sheet(isPresented: Binding(
                get: { !reviewEntries.isEmpty },
                set: { isPresented in if !isPresented { reviewEntries = [] } }
            )) {
                NavigationStack {
                    ReviewConfirmView(entries: $reviewEntries) {
                        appModel.addDetectedPantryEntries(reviewEntries, source: reviewSource, rawInput: reviewRawInput)
                        reviewEntries = []
                        reviewRawInput = nil
                    }
                }
            }
            .onReceive(scannerVM.$detectedCode.compactMap { $0 }) { code in
                Task {
                    let entry = await scannerVM.resolveEntry(for: code)
                    reviewEntries = [entry]
                    reviewSource = .scanned
                    reviewRawInput = entry.rawText
                }
            }
        }
    }

    private var typedEntryContent: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Add ingredient", text: $typedIngredient)
                    .textInputAutocapitalization(.words)
                    .focused($isIngredientInputFocused)
                    .onChange(of: typedIngredient) { _, newValue in
                        appModel.pantry.updateEntryText(newValue)
                        appModel.objectWillChange.send()
                    }
                TextField("Qty", text: $quantity)
                    .frame(width: 72)
                    .textFieldStyle(.roundedBorder)
                Button("Add") {
                    appModel.addPantryItem(name: typedIngredient, quantity: quantity)
                    typedIngredient = ""
                    quantity = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(typedIngredient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Text("Quick add staples")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(staples, id: \.self) { staple in
                        Button(staple) {
                            typedIngredient = staple
                            appModel.addPantryItem(name: staple, quantity: "—")
                            typedIngredient = ""
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if !appModel.pantry.suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(appModel.pantry.suggestions) { suggestion in
                            Button(suggestion.name) {
                                appModel.pantry.chooseSuggestion(suggestion)
                                typedIngredient = suggestion.name
                                appModel.objectWillChange.send()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var speakEntryContent: some View {
        VStack(spacing: 12) {
            Button {
                speechVM.toggleRecording()
            } label: {
                Image(systemName: speechVM.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(speechVM.isRecording ? .red : .orange)
            }
            Text(speechVM.isRecording ? "Listening… tap to stop" : "Tap to speak ingredients")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !speechVM.transcript.isEmpty {
                Text(speechVM.transcript)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let error = speechVM.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !speechVM.isRecording, !speechVM.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Review & Confirm") {
                    reviewEntries = PantryInputProcessor.detectEntries(from: speechVM.transcript)
                    reviewSource = .spoken
                    reviewRawInput = speechVM.transcript
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 6)
    }

    private var scanEntryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            BarcodeScannerView(viewModel: scannerVM)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            if let status = scannerVM.statusText {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ReviewConfirmView: View {
    @Binding var entries: [DetectedPantryEntry]
    var onConfirm: () -> Void

    var body: some View {
        List {
            Section("Detected Items") {
                ForEach($entries) { $entry in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Detected text", text: $entry.rawText)
                            .onSubmit { rematch(entryID: entry.id) }
                        HStack {
                            TextField("Ingredient", text: $entry.matchedIngredientName)
                                .onSubmit { rematch(entryID: entry.id) }
                            Spacer()
                            confidenceBadge(entry.confidence)
                        }
                    }
                }
                .onDelete { offsets in
                    entries.remove(atOffsets: offsets)
                }
            }
        }
        .navigationTitle("Review & Confirm")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Re-match all") {
                    for idx in entries.indices {
                        rematch(entryID: entries[idx].id)
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Confirm") { onConfirm() }
                    .disabled(entries.isEmpty)
            }
        }
    }

    @ViewBuilder
    private func confidenceBadge(_ confidence: IngredientMatchConfidence) -> some View {
        let label: String
        let color: Color
        switch confidence {
        case .high:
            label = "High"
            color = .green
        case .medium:
            label = "Medium"
            color = .orange
        case .needsReview:
            label = "Needs review"
            color = .red
        }

        Text(label)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
    }

    private func rematch(entryID: UUID) {
        guard let idx = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let updated = PantryInputProcessor.detectEntries(from: entries[idx].matchedIngredientName).first
        if let updated {
            entries[idx].matchedIngredientName = updated.matchedIngredientName
            entries[idx].matchedIngredientID = updated.matchedIngredientID
            entries[idx].confidence = updated.confidence
        } else {
            entries[idx].confidence = .needsReview
            entries[idx].matchedIngredientID = nil
        }
    }
}

struct RecipesTabView: View {
    @EnvironmentObject private var appModel: YesChefAppModel

    var body: some View {
        NavigationStack {
            List {
                Section("Cook Now") {
                    if appModel.recipesVM.state.cookNow.isEmpty {
                        Text("No exact matches yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appModel.recipesVM.state.cookNow) { match in
                            NavigationLink {
                                RecipeDetailView(match: match)
                            } label: {
                                RecipeCard(match: match)
                            }
                        }
                    }
                }

                Section("Almost There") {
                    if appModel.recipesVM.state.almostThere.isEmpty {
                        Text("You’re close! Add 1–2 ingredients to unlock more meals.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appModel.recipesVM.state.almostThere) { match in
                            NavigationLink {
                                RecipeDetailView(match: match)
                            } label: {
                                RecipeCard(match: match)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Recipes")
        }
    }
}

struct RecipeCard: View {
    let match: RecipeMatchResult

    var body: some View {
        HStack(spacing: 12) {
            MacroRing(nutrition: match.recipe.nutrition, lineWidth: 8)
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 6) {
                Text(match.recipe.name)
                    .font(.headline)
                HStack {
                    Label("\(match.recipe.totalMinutes)m", systemImage: "clock")
                    Text("•")
                    Text("Missing \(match.missingCount)")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(match.missingCount == 0 ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                    Text("\(Int(match.pantryMatchPercentage * 100))% match")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !match.badges.isEmpty {
                    HStack {
                        ForEach(match.badges.prefix(2), id: \.self) { badge in
                            Text(badge)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RecipeDetailView: View {
    @EnvironmentObject private var appModel: YesChefAppModel
    @State private var servings = 1
    let match: RecipeMatchResult

    private var availableIngredients: [RecipeIngredient] {
        match.recipe.ingredients.filter { !match.missingIngredients.contains($0) }
    }

    private var scaledNutrition: NutritionSummary {
        match.recipe.nutrition.scaled(forServings: servings)
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    MacroRing(nutrition: scaledNutrition, lineWidth: 16)
                        .frame(width: 160, height: 160)
                    Text("\(scaledNutrition.calories) cal")
                        .font(.title3.bold())
                    Text("P \(scaledNutrition.protein)g • C \(scaledNutrition.carbs)g • F \(scaledNutrition.fat)g")
                        .foregroundStyle(.secondary)
                    Stepper("Servings: \(servings)", value: $servings, in: 1...8)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section("You Have") {
                ForEach(availableIngredients, id: \.ingredientName) { ingredient in
                    Label("\(ingredient.ingredientName) (\(ingredient.quantity))", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            Section("Missing") {
                if match.missingIngredients.isEmpty {
                    Text("You have everything needed.")
                } else {
                    ForEach(match.missingIngredients, id: \.ingredientName) { ingredient in
                        Label("\(ingredient.ingredientName) (\(ingredient.quantity))", systemImage: "cart.badge.plus")
                    }
                }
            }

            Button("Cooked it") {
                appModel.logCooked(recipeID: match.recipe.id, servings: servings)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            if !match.missingIngredients.isEmpty {
                Button("Add Missing to Shop List") {
                    appModel.addMissingToShop(match.missingIngredients)
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(match.recipe.name)
    }
}

struct ShopTabView: View {
    @EnvironmentObject private var appModel: YesChefAppModel
    @State private var expandedUnlockIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                Section("Unlock Ingredient") {
                    if appModel.unlockSuggestions.isEmpty {
                        Text("You already have strong coverage for recommended recipes.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appModel.unlockSuggestions) { suggestion in
                            VStack(alignment: .leading, spacing: 6) {
                                Button {
                                    appModel.addUnlockIngredientToShop(suggestion.ingredient.name)
                                } label: {
                                    HStack {
                                        Text(suggestion.ingredient.name)
                                        Spacer()
                                        Text("Unlocks \(suggestion.unlockCount) recipes")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Button(expandedUnlockIDs.contains(suggestion.id) ? "Hide why" : "Why") {
                                    if expandedUnlockIDs.contains(suggestion.id) {
                                        expandedUnlockIDs.remove(suggestion.id)
                                    } else {
                                        expandedUnlockIDs.insert(suggestion.id)
                                    }
                                }
                                .font(.caption)

                                if expandedUnlockIDs.contains(suggestion.id) {
                                    Text(suggestion.recipeNames.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Section("Shopping List") {
                    if appModel.shop.shoppingList.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your shopping list is empty.")
                                .foregroundStyle(.secondary)
                            Button("Add missing ingredients from recipes") {
                                appModel.addMissingFromAlmostThereRecipes()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        ForEach(appModel.shop.shoppingList, id: \.ingredientName) { ingredient in
                            Text("\(ingredient.ingredientName) — \(ingredient.quantity)")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Shop")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !appModel.shop.shoppingList.isEmpty {
                        ShareLink(item: appModel.shareableShoppingList) {
                            Label("Share list", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }
}

struct ProfileTabView: View {
    @EnvironmentObject private var appModel: YesChefAppModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Diet Focus") {
                    ForEach(DietTag.allCases, id: \.self) { tag in
                        Toggle(tag.rawValue, isOn: Binding(
                            get: { appModel.userPrefs.enabledDiets.contains(tag) },
                            set: { enabled in
                                if enabled {
                                    appModel.userPrefs.enabledDiets.insert(tag)
                                } else {
                                    appModel.userPrefs.enabledDiets.remove(tag)
                                }
                            }
                        ))
                    }
                }

                Section("Allergens") {
                    ForEach(Allergen.allCases, id: \.self) { allergen in
                        Toggle(allergen.rawValue, isOn: Binding(
                            get: { appModel.userPrefs.allergens.contains(allergen) },
                            set: { enabled in
                                if enabled {
                                    appModel.userPrefs.allergens.insert(allergen)
                                } else {
                                    appModel.userPrefs.allergens.remove(allergen)
                                }
                            }
                        ))
                    }
                }

                Section("Macro Targets (optional)") {
                    MacroTargetField(title: "Calories", suffix: "cal", value: Binding(
                        get: { appModel.userPrefs.targetCalories },
                        set: { appModel.userPrefs.targetCalories = $0 }
                    ))
                    MacroTargetField(title: "Protein", value: Binding(
                        get: { appModel.userPrefs.targetProtein },
                        set: { appModel.userPrefs.targetProtein = $0 }
                    ))
                    MacroTargetField(title: "Carbs", value: Binding(
                        get: { appModel.userPrefs.targetCarbs },
                        set: { appModel.userPrefs.targetCarbs = $0 }
                    ))
                    MacroTargetField(title: "Fat", value: Binding(
                        get: { appModel.userPrefs.targetFat },
                        set: { appModel.userPrefs.targetFat = $0 }
                    ))
                }

                Section("Testing") {
                    Button("Reset onboarding") {
                        appModel.resetOnboarding()
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

struct MacroTargetField: View {
    let title: String
    var suffix: String = "g"
    @Binding var value: Int?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(suffix, text: Binding(
                get: { value.map(String.init) ?? "" },
                set: { value = Int($0) }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 80)
        }
    }
}

struct MacroRing: View {
    let nutrition: NutritionSummary
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.15), lineWidth: lineWidth)
            arc(value: nutrition.protein, color: .red, start: .degrees(-90))
            arc(value: nutrition.carbs, color: .blue, start: angle(after: nutrition.protein))
            arc(value: nutrition.fat, color: .orange, start: angle(after: nutrition.protein + nutrition.carbs))
        }
        .overlay {
            VStack(spacing: 0) {
                Text("P/C/F")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(nutrition.protein)/\(nutrition.carbs)/\(nutrition.fat)")
                    .font(.caption2.bold())
            }
        }
    }

    private func angle(after consumed: Int) -> Angle {
        .degrees(-90 + 360.0 * Double(consumed) / Double(nutrition.totalMacroGrams))
    }

    private func arc(value: Int, color: Color, start: Angle) -> some View {
        Circle()
            .trim(from: 0, to: CGFloat(Double(value) / Double(nutrition.totalMacroGrams)))
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(start)
    }
}

@MainActor
final class SpeechCaptureViewModel: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording() {
        errorMessage = nil
        transcript = ""

        SFSpeechRecognizer.requestAuthorization { [weak self] auth in
            guard auth == .authorized else {
                Task { @MainActor in self?.errorMessage = "Speech permission denied." }
                return
            }
            AVAudioApplication.requestRecordPermission { granted in
                guard granted else {
                    Task { @MainActor in self?.errorMessage = "Microphone permission denied." }
                    return
                }
                Task { @MainActor in self?.beginSession() }
            }
        }
    }

    private func beginSession() {
        let request = SFSpeechAudioBufferRecognitionRequest()
        self.request = request
        request.shouldReportPartialResults = true

        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Unable to start audio engine."
            return
        }

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in self.transcript = result.bestTranscription.formattedString }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in self.stopRecording() }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        isRecording = false
    }
}

@MainActor
final class BarcodeScannerViewModel: NSObject, ObservableObject {
    @Published var detectedCode: String?
    @Published var statusText: String? = "Align barcode inside the frame"

    private var lastCode: String?

    func didScan(code: String) {
        guard code != lastCode else { return }
        lastCode = code
        detectedCode = code
        statusText = "Detected \(code). Looking up item…"
    }

    func resolveEntry(for code: String) async -> DetectedPantryEntry {
        defer { statusText = "Align barcode inside the frame" }
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(code).json") else {
            return PantryInputProcessor.detectBarcodeEntry(productName: nil, barcode: code)
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let payload = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
            return PantryInputProcessor.detectBarcodeEntry(productName: payload.product?.productName, barcode: code)
        } catch {
            statusText = "Lookup failed. You can still review and edit."
            return PantryInputProcessor.detectBarcodeEntry(productName: nil, barcode: code)
        }
    }
}

private struct OpenFoodFactsResponse: Decodable {
    let product: Product?

    struct Product: Decodable {
        let productName: String?

        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
        }
    }
}

struct BarcodeScannerView: UIViewControllerRepresentable {
    @ObservedObject var viewModel: BarcodeScannerViewModel

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        private let viewModel: BarcodeScannerViewModel

        init(viewModel: BarcodeScannerViewModel) {
            self.viewModel = viewModel
        }

        func scannerViewController(_ controller: ScannerViewController, didDetect code: String) {
            viewModel.didScan(code: code)
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func scannerViewController(_ controller: ScannerViewController, didDetect code: String)
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?

    private let session = AVCaptureSession()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !session.isRunning { session.startRunning() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if session.isRunning { session.stopRunning() }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce]

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.addSublayer(preview)
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = object.stringValue
        else { return }
        delegate?.scannerViewController(self, didDetect: value)
    }
}
#endif
