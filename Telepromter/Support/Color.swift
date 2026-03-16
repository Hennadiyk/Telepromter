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
    // Sound level bar colors
    let babyblue = Color("BabyBlueColor")
    //Theme Gradient
    let gradientLow = Color("GradientLow")
    let gradientHigh = Color("GradientHigh")
    
    
    
}

struct PlainGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            configuration.content
            
        }.padding(30).background(.ultraThinMaterial).cornerRadius(30).opacity(0.8)
    }
}



enum themeSwitching: String, CaseIterable, Identifiable {
    
    case white
    case pink
    case teal
    case blue
    case red
    
    
    var id: Int {
        switch self {
            case .white: return 0
            case .pink: return 1
            case .teal: return 2
            case .blue: return 3
            case .red: return 4
                
        }
    }
    
    var colorTop: Color {
        switch self {
                
            case .white: return Color(.black)
            case .pink: return Color(.pink)
            case .teal: return Color(.teal)
            case .blue: return Color(.yellow)
            case .red: return Color(.red)
                
        }
    }
    var colorBottom: Color {
        switch self {
                
            case .white: return Color(.white)
            case .pink: return Color(.green)
            case .teal: return Color(.purple)
            case .blue: return Color(.blue)
            case .red: return Color(.cyan)
                
        }
    }
    
    
}
