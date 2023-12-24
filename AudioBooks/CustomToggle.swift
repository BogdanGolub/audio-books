//
//  CustomToggle.swift
//  AudioBooks
//
//  Created by Bohdan on 13.12.2023.
//

import SwiftUI

@available(iOS 15.0, *)
public struct ThumbToggle: View {
    
    @Binding public var status:Bool
    @State public var isOpen:Bool
    public var iconClose:String = "sun.max.fill"
    public var iconClsClr:Color = .black.opacity(0.8)
    public var backClose:Color = .black
    
    public var iconOpen:String = "moon.stars.fill"
    public var iconOpnClr:Color = .orange
    public var backOpen:Color = .blue.opacity(0.6)
    
    
    public var thumbColor:Color = .white
    
    
    
    public init(status: Binding<Bool>,
                iconClose:String = "headphones",
                iconClsClr:Color = .white,
                backClose:Color = .white,
                iconOpen:String = "text.alignleft",
                iconOpnClr:Color = .white,
                backOpen:Color = .white,
                thumbColor:Color = Color(red: 42/255, green: 100/255, blue: 246/255)) {
        _status = status
        self.isOpen = status.wrappedValue
        self.iconClose = iconClose
        self.iconClsClr = iconClsClr
        self.backClose = backClose
        self.iconOpen = iconOpen
        
        self.iconOpnClr = iconOpnClr
        self.backOpen = backOpen
        self.thumbColor = thumbColor
        
    }
    
    public var body: some View {
        Capsule(style: .continuous)
            .fill(isOpen ? backOpen:backClose)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .animation(.default, value: isOpen)
            .frame(width: 130, height: 72)
            .overlay(alignment: isOpen ? .trailing:.leading) {
                Circle().fill(thumbColor).padding(4).overlay {
                    Image(systemName: isOpen ? iconOpen:iconClose)
                        .scaleEffect(1.2)
                        .font(.callout).foregroundColor(isOpen ? iconOpnClr:iconClsClr)
                        .animation(.default, value: isOpen)
                }
            }
            .overlay(alignment: !isOpen ? .trailing:.leading) {
                Circle().fill(.clear).padding(4).overlay {
                    Image(systemName: !isOpen ? iconOpen:iconClose)
                        .scaleEffect(1.2)
                        .font(.callout).foregroundColor(.black)
                        .animation(.default, value: isOpen)
                }
            }
        
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.825)) {
                    status.toggle()
                }
            }.onChange(of: status) { newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.825)) {
                    isOpen = newValue
                }
            }
    }
}

@available(iOS 13.0.0, *)
struct ThumbToggle_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 15.0, *) {
            VStack {
                ThumbToggle(status: .constant(false))
                ThumbToggle(status: .constant(true))
            }
        } else {
            // Fallback on earlier versions
        }
    }
}
