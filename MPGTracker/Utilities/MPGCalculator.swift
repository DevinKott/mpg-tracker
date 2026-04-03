//
//  MPGCalculator.swift
//  MPGTracker
//
//  Created by Devin Kott on 4/2/26.
//

/// Pure math functions for fuel efficiency calculations.
///
/// Used by the view layer for live-preview calculations. Contains no SwiftData
/// imports and carries no state — safe to call from anywhere.
enum MPGCalculator {

    /// Calculates fuel efficiency in miles per gallon.
    ///
    /// - Parameters:
    ///   - miles: Distance driven since the last reset.
    ///   - gallons: Gallons pumped at this fill-up.
    /// - Returns: Miles per gallon, or `0` if `gallons` is zero or negative.
    static func calculateMPG(miles: Double, gallons: Double) -> Double {
        guard gallons > 0 else { return 0 }
        return miles / gallons
    }

    /// Calculates the cost per gallon from a total price and gallon count.
    ///
    /// - Parameters:
    ///   - totalPrice: Total dollar amount paid at the pump.
    ///   - gallons: Gallons pumped at this fill-up.
    /// - Returns: Price per gallon, or `0` if `gallons` is zero or negative.
    static func calculatePricePerGallon(totalPrice: Double, gallons: Double) -> Double {
        guard gallons > 0 else { return 0 }
        return totalPrice / gallons
    }
}
