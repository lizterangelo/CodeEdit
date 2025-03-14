//
//  ExtensionsSettingsView.swift
//  CodeEdit
//
//  Created by Abe Malla on 2/2/25.
//

import SwiftUI

struct LanguageServersView: View {
    @State private var didError = false
    @State private var installationFailure: InstallationFailure?
    @State private var registryItems: [RegistryItem] = []
    @State private var isLoading = true

    var body: some View {
        SettingsForm {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
            } else {
                Section {
                    List(registryItems, id: \.name) { item in
                        LanguageServerRowView(
                            packageName: item.name,
                            subtitle: item.description,
                            isInstalled: RegistryManager.shared.installedLanguageServers[item.name] != nil,
                            isEnabled: RegistryManager.shared.installedLanguageServers[item.name]?.isEnabled ?? false,
                            onCancel: { },
                            onInstall: {
                                do {
                                    try await RegistryManager.shared.installPackage(package: item)
                                } catch {
                                    installationFailure = InstallationFailure(error: error.localizedDescription)
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    }
                }
            }
        }
        .onAppear {
            loadRegistryItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .RegistryUpdatedNotification)) { _ in
            loadRegistryItems()
        }
        .alert(
            "Installation Failed",
            isPresented: $didError,
            presenting: installationFailure
        ) { _ in
            Button("Dismiss") { }
        } message: { details in
            Text(details.error)
        }
    }

    private func loadRegistryItems() {
        isLoading = true
        registryItems = RegistryManager.shared.registryItems
        if !registryItems.isEmpty {
            isLoading = false
        }
    }
}

private struct InstallationFailure: Identifiable {
    let error: String
    let id = UUID()
}
