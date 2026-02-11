#if canImport(SwiftUI)
import SwiftUI
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

final class YesChefAppModel: ObservableObject {
    @Published var pantry = PantryViewModel()
    @Published var recipesVM = RecipesViewModel()
    @Published var shop = ShopViewModel()
    @Published var userPrefs = UserPrefs(displayName: "Chef", dietaryStyle: "Balanced", showMacroPlaceholders: true)

    init() {
        if let loaded = try? RecipeLoader.loadSeededRecipes() {
            recipesVM.reloadRecipes(loaded)
            recipesVM.updateMatches(pantryItems: pantry.pantryItems)
        }
    }

    func refreshMatches() {
        recipesVM.updateMatches(pantryItems: pantry.pantryItems)
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            PantryTabView()
                .tabItem {
                    Label("Pantry", systemImage: "cabinet")
                }
            RecipesTabView()
                .tabItem {
                    Label("Recipes", systemImage: "fork.knife")
                }
            ShopTabView()
                .tabItem {
                    Label("Shop", systemImage: "cart")
                }
            ProfileTabView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
    }
}

struct PantryTabView: View {
    @EnvironmentObject private var appModel: YesChefAppModel
    @State private var typedIngredient = ""
    @State private var quantity = ""
    @State private var showConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Add Ingredient") {
                    TextField("Type ingredient", text: $typedIngredient)
                        .onChange(of: typedIngredient) { _, newValue in
                            appModel.pantry.updateEntryText(newValue)
                        }
                    TextField("Quantity", text: $quantity)

                    if !appModel.pantry.suggestions.isEmpty {
                        ForEach(appModel.pantry.suggestions) { ingredient in
                            Button(ingredient.name) {
                                appModel.pantry.chooseSuggestion(ingredient)
                                typedIngredient = ingredient.name
                            }
                        }
                    }

                    Button("Confirm") {
                        showConfirm = true
                    }
                    .disabled(typedIngredient.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .confirmationDialog("Save to pantry?", isPresented: $showConfirm, titleVisibility: .visible) {
                        Button("Save") {
                            appModel.pantry.updateEntryText(typedIngredient)
                            if appModel.pantry.confirmSave(quantity: quantity.isEmpty ? "1" : quantity) != nil {
                                typedIngredient = ""
                                quantity = ""
                                appModel.refreshMatches()
                            }
                        }
                    }
                }

                Section("Pantry Items") {
                    ForEach(appModel.pantry.pantryItems) { item in
                        VStack(alignment: .leading) {
                            Text(item.ingredientName).font(.headline)
                            Text(item.quantity).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Pantry")
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
                        Text("Add a few more pantry items to unlock recipes.")
                    } else {
                        ForEach(appModel.recipesVM.state.almostThere.filter { !$0.isCookNow }) { match in
                            NavigationLink {
                                RecipeDetailView(match: match)
                            } label: {
                                RecipeCard(match: match)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recipes")
        }
    }
}

struct RecipeCard: View {
    let match: RecipeMatchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(match.recipe.name).font(.headline)
            Text("Missing: \(match.missingCount) • Time: \(match.recipe.totalMinutes)m")
                .font(.subheadline)
            Text(match.recipe.macroSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct RecipeDetailView: View {
    @EnvironmentObject private var appModel: YesChefAppModel
    let match: RecipeMatchResult

    var body: some View {
        List {
            Section("Macros") {
                Text(match.recipe.macroSummary)
            }
            Section("Have") {
                ForEach(match.recipe.ingredients.filter { ingredient in
                    !match.missingIngredients.contains(ingredient)
                }, id: \.ingredientName) { ingredient in
                    Text("✅ \(ingredient.ingredientName) (\(ingredient.quantity))")
                }
            }
            Section("Missing") {
                if match.missingIngredients.isEmpty {
                    Text("You have everything!")
                } else {
                    ForEach(match.missingIngredients, id: \.ingredientName) { ingredient in
                        Text("⬜️ \(ingredient.ingredientName) (\(ingredient.quantity))")
                    }
                }
            }
            if !match.missingIngredients.isEmpty {
                Button("Add Missing to Shop List") {
                    appModel.shop.addMissing(match.missingIngredients)
                }
            }
        }
        .navigationTitle(match.recipe.name)
    }
}

struct ShopTabView: View {
    @EnvironmentObject private var appModel: YesChefAppModel

    var body: some View {
        NavigationStack {
            List {
                if appModel.shop.shoppingList.isEmpty {
                    Text("Your shopping list is empty.")
                } else {
                    ForEach(appModel.shop.shoppingList, id: \.ingredientName) { ingredient in
                        Text("\(ingredient.ingredientName) — \(ingredient.quantity)")
                    }
                }
            }
            .navigationTitle("Shop")
        }
    }
}

struct ProfileTabView: View {
    @EnvironmentObject private var appModel: YesChefAppModel

    var body: some View {
        NavigationStack {
            Form {
                TextField("Display Name", text: Binding(
                    get: { appModel.userPrefs.displayName },
                    set: { appModel.userPrefs.displayName = $0 }
                ))
                TextField("Dietary Style", text: Binding(
                    get: { appModel.userPrefs.dietaryStyle },
                    set: { appModel.userPrefs.dietaryStyle = $0 }
                ))
                Toggle("Show Macro Placeholders", isOn: Binding(
                    get: { appModel.userPrefs.showMacroPlaceholders },
                    set: { appModel.userPrefs.showMacroPlaceholders = $0 }
                ))
            }
            .navigationTitle("Profile")
        }
    }
}
#endif
