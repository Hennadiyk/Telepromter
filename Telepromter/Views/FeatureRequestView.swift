//
//  FeatureRequestView.swift
//  Teleprompter DE
//
//  Created by Hennadiy Kvasov on 7/17/25.
//
import SwiftUI
import FirebaseFirestore  // Add this import

struct FeatureRequestView: View {
    @State private var featureText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        ZStack{
            BackgroundView()
                .opacity(0.4)
            Form {
                Section(header: Text("Describe your feature request")) {
                    TextEditor(text: $featureText)
                        .frame(minHeight: 100)
                }
                Button("Submit Request") {
                    submitFeatureRequest()
                }
                .disabled(isSubmitting || featureText.isEmpty)
            }.scrollContentBackground(.hidden)
            
                .navigationTitle("Request Feature")
                .alert("Submission Status", isPresented: $showAlert) {
                    Button("OK") { }
                } message: {
                    Text(alertMessage)
                }
        }
        
    }
    
    private func submitFeatureRequest() {
        guard !featureText.isEmpty else {
            alertMessage = "Please enter a description."
            showAlert = true
            return
        }
        isSubmitting = true
        
        let db = Firestore.firestore()  // Get Firestore instance
        db.collection("feature_requests").addDocument(data: [
            "text": featureText,
            "timestamp": Timestamp(date: Date())
        ]) { error in
            DispatchQueue.main.async {
                self.isSubmitting = false
                if let error = error {
                    self.alertMessage = "Error: \(error.localizedDescription)"
                } else {
                    self.alertMessage = "Request sent successfully!"
                    self.featureText = ""  // Clear input
                }
                self.showAlert = true
            }
        }
    }
}

#Preview {
    NavigationStack {
        FeatureRequestView()
    }
}
