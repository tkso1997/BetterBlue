//
//  HTTPLogComponents.swift
//  BetterBlue
//
//  Created by Mark Schmidt on 8/25/25.
//

import BetterBlueKit
import SwiftUI

struct JSONBodyView: View {
    let content: NSAttributedString
    @Binding var showingShareSheet: Bool
    @Namespace private var transition

    var body: some View {

        Text(AttributedString(content))
            .font(.system(.caption, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: [content])
                .navigationTransition(
                    .zoom(sourceID: "json-share)", in: transition ),
                )
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

struct HTTPLogFilterSheet: View {
    @Binding var selectedRequestTypes: Set<HTTPRequestType>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(HTTPRequestType.allCases, id: \.self) { requestType in
                    Button {
                        if selectedRequestTypes.contains(requestType) {
                            selectedRequestTypes.remove(requestType)
                        } else {
                            selectedRequestTypes.insert(requestType)
                        }
                    } label: {
                        HStack {
                            Image(
                                systemName: selectedRequestTypes.contains(requestType) ?
                                    "checkmark.square.fill" : "square",
                            )
                            .foregroundColor(selectedRequestTypes.contains(requestType) ? .accentColor : .secondary)
                            Text(requestType.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Filter Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(
                        selectedRequestTypes.count == HTTPRequestType.allCases.count ?
                            "Deselect All" : "Select All",
                    ) {
                        if selectedRequestTypes.count == HTTPRequestType.allCases.count {
                            selectedRequestTypes.removeAll()
                        } else {
                            selectedRequestTypes = Set(HTTPRequestType.allCases)
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
