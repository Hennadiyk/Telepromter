////
////  TermsofuseView.swift
////  Teleprompter DE
////
////  Created by Hennadiy Kvasov on 7/17/25.
////
//
//import SwiftUI
//
//struct TermsofuseView: View {
//    let sections: [(title: String, content: String)] = [
//        ("Terms of Use for Teleprompter DE", "\n\nWelcome to Teleprompter DE (the \"App\"), a teleprompter application designed to assist users in delivering speeches, presentations, and recordings by displaying scrolling text. These Terms of Use (\"Terms\") govern your access to and use of the App, including all functionality and services offered on or through the App. The App is owned and operated by Hennadiy Kvasov (\"we,\" \"us,\" or \"our\").\n\nBy downloading, installing, accessing, or using the App, you agree to be bound by these Terms. If you do not agree to these Terms, you must not use the App.\n\nWe may update these Terms periodically. Your continued use of the App after changes constitutes acceptance of the updated Terms."),
//        ("1. Eligibility", "You must be at least 13 years old (or the age of majority in your jurisdiction, if higher) to use the App. If you are under the age of majority, you must have the consent of a parent or legal guardian. By using the App, you represent and warrant that you meet these eligibility requirements."),
//        ("2. License Grant and App Requirements", "Subject to your compliance with these Terms, we grant you a limited, non-exclusive, non-transferable, non-sublicensable, revocable license to download, install, and use the App on your personal device(s) for your own non-commercial use.\n\nThe App requires an internet connection for subscription verification purposes. This allows us to confirm your active subscription status through Apple's services. Without an internet connection, certain features related to subscriptions may not function properly.\n\nYou may not:\n- Modify, disassemble, decompile, or reverse-engineer the App.\n- Rent, lease, lend, sell, redistribute, or sublicense the App.\n- Use the App for any illegal or unauthorized purpose.\n- Remove or alter any proprietary notices or labels in the App."),
//        ("3. In-App Purchases", "The App may offer in-app purchases or subscriptions, which are processed and managed by Apple Inc. through the App Store. We do not collect, store, or have access to your credit card information or other payment details. All payment transactions are subject to Apple’s terms and conditions, including their payment and refund policies. For questions about purchases, please contact Apple Support or refer to the App Store."),
//        ("4. User Content and Data", "The App does not collect, store, or transmit images, text, or recorded videos created or inputted by you during your use of the App. Any text you input for teleprompter scripts, as well as any videos you record using the App, are processed and stored locally on your device and are not uploaded to our servers or sent to any third parties. You are solely responsible for maintaining backups of any data or recordings you create in the App."),
//        ("5. Prohibited Conduct", "You agree not to:\n- Use the App in any way that violates applicable laws or third-party rights.\n- Upload or transmit viruses, malware, or harmful code.\n- Engage in harassment, hate speech, or discriminatory behavior.\n- Interfere with the App’s functionality or security.\n- Use automated systems (e.g., bots, scrapers) to access the App."),
//        ("6. Intellectual Property", "The App, including all software, design, graphics, and other materials, is owned by us or our licensors and protected by copyright, trademark, and other intellectual property laws. You may not copy, reproduce, or distribute any part of the App except as expressly permitted.\n\n\"Teleprompter DE\" and associated logos are our trademarks. You may not use them without our prior written consent."),
//        ("7. Privacy", "As the App does not collect images, text, recorded videos, or other personal data beyond what is necessary for subscription verification (handled via Apple), we do not process or store personal information related to your use of the App’s core functionality. Any data processed locally on your device remains under your control. For more details, please review our Privacy Policy [link to Privacy Policy if available]. By using the App, you consent to our data practices as described therein."),
//        ("8. Disclaimers", "THE APP IS PROVIDED \"AS IS\" AND \"AS AVAILABLE\" WITHOUT WARRANTIES OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.\n\nWe do not warrant that the App will be error-free, secure, or uninterrupted, or that it will function without an internet connection for all features. We are not responsible for any loss or damage arising from your use of the App, including data loss or hardware issues."),
//        ("9. Limitation of Liability", "TO THE MAXIMUM EXTENT PERMITTED BY LAW, WE SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING LOSS OF PROFITS, DATA, OR GOODWILL, ARISING FROM YOUR USE OF THE APP, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.\n\nOur total liability to you shall not exceed the amount you paid for the App or related in-app purchases in the preceding 12 months, if any."),
//        ("10. Indemnification", "You agree to indemnify, defend, and hold harmless us, our affiliates, officers, directors, employees, and agents from any claims, liabilities, damages, losses, or expenses arising from your use of the App or your violation of these Terms."),
//        ("11. Termination", "We may terminate or suspend your access to the App at any time, without notice, for any reason, including breach of these Terms. Upon termination, your license to use the App ends, and you must delete all copies.\n\nSections that by their nature should survive termination (e.g., disclaimers, limitations of liability, indemnification) will continue to apply."),
//        ("12. Governing Law", "These Terms are governed by the laws of the State of California, United States, without regard to conflict of laws principles. Any disputes shall be resolved exclusively in the courts located in Los Angeles, California."),
//        ("13. Changes to the App", "We may update, modify, or discontinue the App or any features at any time without notice. We are not liable for any such changes."),
//        ("14. Miscellaneous", "These Terms constitute the entire agreement between you and us regarding the App. If any provision is held invalid, the remainder shall continue in full force.\n\nWe may assign these Terms without your consent. You may not assign them without our written consent.\n\nNo waiver of any term shall be deemed a further or continuing waiver."),
//        ("Contact Us", "If you have questions about these Terms, contact us at contact@hennadiy.com.")
//    ]
//    
//    var body: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 12) {
//                ForEach(sections, id: \.title) { section in
//                    Text(section.title)
//                        .font(section.title == "Terms of Use for Teleprompter DE" ? .largeTitle : .title2)
//                        .bold()
//                    if section.title == "Terms of Use for Teleprompter DE" {
//                        Text("Effective Date: July 27, 2025")
//                            .font(.subheadline)
//                            .italic()
//                    }
//                    Text(section.content)
//                        .font(.body)
//                }
//            }
//            .padding()
//        }
//        .navigationTitle("Terms of Use")
//    }
//}
//
//#Preview {
//    TermsofuseView()
//}
