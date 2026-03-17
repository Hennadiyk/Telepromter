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
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 40))
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(.gray.opacity(0.2), lineWidth: 1)
                    )
                    .scrollContentBackground(.hidden)

            }
            .padding([.horizontal, .bottom], 16)
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
                            .foregroundStyle(contentVM.textInput.isEmpty ? Color.color.gradientHigh : Color.color.gradientLow)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Text")
                        .font(.title)
                        .foregroundStyle(LinearGradient(colors: [Color.color.gradientLow, Color.color.gradientHigh], startPoint: .leading, endPoint: .trailing))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .tint(LinearGradient(colors: [Color.color.gradientHigh, Color.color.gradientLow], startPoint: .leading, endPoint: .trailing))
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
