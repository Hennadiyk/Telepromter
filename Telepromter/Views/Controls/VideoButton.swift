//
//  VideoButton.swift
//  Telepromter
//
//  Created by Hennadiy Kvasov on 7/2/25.
//

import SwiftUI

struct VideoButton: View {
    @EnvironmentObject var contentVM: ContentViewModel
    
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Button{
                    contentVM.videoOn.toggle()
                    
                } label: {
                    
                    Image(systemName: "video")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 20)
                        .rotationEffect(Angle(degrees: 270))
                        .padding(.vertical, 20)
                        .padding(.horizontal, 2)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .offset(x: -5)
                    
                }
                
            }
            
            
        
        }
      
    }
}



#Preview {
    VideoButton().environmentObject(ContentViewModel())
}
