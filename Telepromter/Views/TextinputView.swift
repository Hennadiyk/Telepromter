//
//  TextInputView.swift
//  Teleprompter
//
//  Created by Hennadiy Kvasov.
//

import SwiftUI

struct TextInputView: View {
    @Environment(ContentViewModel.self) var contentVM
    @State private var viewModel = TextInputViewModel()
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        @Bindable var contentVM = contentVM
        NavigationStack {
            VStack {
                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .padding(.bottom)
                }

                TextEditor(text: $contentVM.textInput)
                    .focused($isEditorFocused)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.gray.opacity(0.2), lineWidth: 1)
                    )
                    .scrollContentBackground(.hidden)

                Spacer(minLength: 16)
            }
            .padding()
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        viewModel.showDocumentPicker = true
                    } label: {
                        Label("Import", systemImage: "doc.text")
                    }

                    Button {
                        contentVM.textInput = ""
                        viewModel.errorMessage = nil
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }

                    Button {
                        isEditorFocused = false
                        contentVM.selectedTab = 1
                    } label: {
                        Text("Done")
                    }
                }
            }
            .navigationTitle("Add Text")
            .sheet(isPresented: $viewModel.showDocumentPicker) {
                DocumentPicker { url in
                    viewModel.handleDocumentSelection(url: url, contentVM: contentVM)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    TextInputView()
        .environment(ContentViewModel())
}
