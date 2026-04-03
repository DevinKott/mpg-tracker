//
//  FillUpEntry.swift
//  MPGTracker
//
//  Created by Devin Kott on 4/2/26.
//

import Foundation
import SwiftData

/// Represents a single fill-up session — the core unit of data in MPGTracker.
///
/// Required fields are `milesDriven` and `gallonsPumped`; everything else is optional.
/// Derived values (`calculatedMPG`, `pricePerGallon`) are kept in sync automatically.
@Model
final class FillUpEntry {

    /// Stable identifier for this entry.
    var id: UUID

    /// When the fill-up was recorded. Auto-set to the current time at creation.
    var date: Date

    /// Miles driven since the last trip odometer reset. Clamped to 0–1000.
    /// Setting this automatically recalculates `calculatedMPG`.
    var milesDriven: Double {
        didSet {
            let clamped = max(0, min(1000, milesDriven))
            if clamped != milesDriven { milesDriven = clamped; return }
            calculatedMPG = MPGCalculator.calculateMPG(miles: milesDriven, gallons: gallonsPumped)
        }
    }

    /// Gallons pumped at this fill-up. Clamped to 0–100.
    /// Setting this automatically recalculates `calculatedMPG` and `pricePerGallon`.
    var gallonsPumped: Double {
        didSet {
            let clamped = max(0, min(100, gallonsPumped))
            if clamped != gallonsPumped { gallonsPumped = clamped; return }
            calculatedMPG = MPGCalculator.calculateMPG(miles: milesDriven, gallons: gallonsPumped)
            pricePerGallon = totalPricePaid.flatMap { gallonsPumped > 0 ? MPGCalculator.calculatePricePerGallon(totalPrice: $0, gallons: gallonsPumped) : nil }
        }
    }

    /// Fuel efficiency for this session (`milesDriven / gallonsPumped`). Persisted and always kept in sync.
    var calculatedMPG: Double

    /// Total dollar amount paid at the pump, if entered.
    /// Setting this automatically recalculates `pricePerGallon`.
    var totalPricePaid: Double? {
        didSet { pricePerGallon = totalPricePaid.flatMap { gallonsPumped > 0 ? MPGCalculator.calculatePricePerGallon(totalPrice: $0, gallons: gallonsPumped) : nil } }
    }

    /// Cost per gallon, derived from `totalPricePaid / gallonsPumped`. `nil` if total price was not entered.
    /// Persisted so the value is available without recalculation.
    var pricePerGallon: Double?

    /// MPG value reported by the vehicle's onboard computer, for comparison with `calculatedMPG`.
    var truckReportedMPG: Double?

    /// Optional free-text note about this fill-up.
    var notes: String?

    init(
        date: Date = Date(),
        milesDriven: Double,
        gallonsPumped: Double,
        totalPricePaid: Double? = nil,
        truckReportedMPG: Double? = nil,
        notes: String? = nil
    ) {
        let miles = max(0, min(1000, milesDriven))
        let gallons = max(0, min(100, gallonsPumped))

        self.id = UUID()
        self.date = date
        self.milesDriven = miles
        self.gallonsPumped = gallons
        self.calculatedMPG = MPGCalculator.calculateMPG(miles: miles, gallons: gallons)
        self.totalPricePaid = totalPricePaid
        self.pricePerGallon = totalPricePaid.flatMap { gallons > 0 ? MPGCalculator.calculatePricePerGallon(totalPrice: $0, gallons: gallons) : nil }
        self.truckReportedMPG = truckReportedMPG
        self.notes = notes
    }

}
