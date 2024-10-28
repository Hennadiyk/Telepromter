//
//  Color.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 10/7/24.
//

import Foundation
import SwiftUI


extension Color {

    static let color = ColorTheme()
    
}

struct ColorTheme {
    
    let theme = Color("ThemeColor")
    let text = Color("TextColor")
    let background = Color("BackgroundColor")
    let secondary = Color("SecColor")
    let interface = Color("InterfaceColor")
  
}

struct PlainGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            configuration.content
            
        }.padding(30).background(.ultraThinMaterial).cornerRadius(30).opacity(0.8)
    }
}
