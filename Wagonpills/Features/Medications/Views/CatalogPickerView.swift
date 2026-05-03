import SwiftUI

struct CatalogPickerView: View {
    @State private var vm: CatalogPickerViewModel
    let onSelect: (CatalogItem) -> Void
    @Environment(\.dismiss) private var dismiss

    init(repository: any CatalogRepository, onSelect: @escaping (CatalogItem) -> Void) {
        _vm = State(wrappedValue: CatalogPickerViewModel(repository: repository))
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            List {
                if vm.isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if let error = vm.searchError {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                } else if vm.results.isEmpty && !vm.searchText.isEmpty && vm.searchText.count >= 2 {
                    Text("No results found.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(vm.results) { item in
                        Button {
                            onSelect(item)
                            dismiss()
                        } label: {
                            CatalogItemRow(item: item)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Search Catalogue")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $vm.searchText, prompt: "Search by name (min. 2 characters)")
            .onChange(of: vm.searchText) { vm.onSearchTextChanged() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Row

private struct CatalogItemRow: View {
    let item: CatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(item.name)
                    .font(.subheadline.bold())
                if let strength = item.strength {
                    Text(strength)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if !item.aliases.isEmpty {
                Text(item.aliases.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Previews

#Preview {
    CatalogPickerView(
        repository: PreviewCatalogRepository(items: [
            CatalogItem(id: 1, name: "Ibuprofen Zentiva", strength: "400 mg",
                        form: "Film-coated tablet", regionCode: "CZ", aliases: ["Ibuprofen", "Ibuprom"]),
            CatalogItem(id: 2, name: "Paracetamol Stada", strength: "500 mg", form: "Tablet", regionCode: "CZ", aliases: ["Paracetamol"]),
            CatalogItem(id: 3, name: "Metformin Teva", strength: "1000 mg", form: "Film-coated tablet", regionCode: "CZ", aliases: [])
        ]),
        onSelect: { _ in }
    )
}
