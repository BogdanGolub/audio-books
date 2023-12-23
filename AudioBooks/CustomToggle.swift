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
    public var iconOpen:String = "sun.max.fill"
    public var iconOpnClr:Color = .black.opacity(0.8)
    public var backOpen:Color = .black
    
    public var iconClose:String = "moon.stars.fill"
    public var iconClsClr:Color = .orange
    public var backClose:Color = .blue.opacity(0.6)
    
    
    public var thumbColor:Color = .white
    
    
    
    public init(status: Binding<Bool>, iconClose:String = "sun.max.fill", iconClsClr:Color = .orange, backClose:Color = .black,iconOpen:String = "moon.stars.fill",iconOpnClr:Color = .black.opacity(0.8),backOpen:Color = .blue.opacity(0.6),thumbColor:Color = .white) {
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
            .animation(.default, value: isOpen)
            .frame(width: 130, height: 72)
            .overlay(alignment: .trailing) {
                Circle().fill(backClose).padding(4).overlay {
                    Image(systemName: isOpen ? iconOpen:iconClose)
                        .font(.callout).foregroundColor(isOpen ? iconOpnClr:iconOpnClr)
                        .animation(.default, value: isOpen)
                }
            }
            .overlay(alignment: .leading) {
                Circle().fill(backOpen).padding(4).overlay {
                    Image(systemName: isOpen ? iconOpen:iconClose)
                        .font(.callout).foregroundColor(isOpen ? iconOpnClr:iconClsClr)
                        .animation(.default, value: isOpen)
                }
            }
        
            .onTapGesture {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.52)) {
                    status.toggle()
                }
            }.onChange(of: status) { newValue in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.52)) {
                    isOpen = newValue
                }
            }
    }
}

@available(iOS 13.0.0, *)
struct ThumbToggle_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 15.0, *) {
            ThumbToggle(status: .constant(false),
                        iconClose: "headphones",
                        iconClsClr: .white,
                        backClose: .white,
                        iconOpen: "text.alignleft",
                        iconOpnClr: .black,
                        backOpen: .blue,
                        thumbColor: .white)
        } else {
            // Fallback on earlier versions
        }
    }
}
