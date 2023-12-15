//
//  DateFormatter.swift
//  AudioBooks
//
//  Created by Bohdan on 14.12.2023.
//

import Foundation

let dateComponentsFormatter: DateComponentsFormatter = {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = [.minute, .second]
  formatter.zeroFormattingBehavior = .pad
  return formatter
}()
