import Foundation

/// A calendar day in the simulation's proleptic Gregorian timeline.
///
/// Keeping time as date components prevents device time zones and daylight-saving
/// changes from moving a save to another day.
public struct SimulationDate: Codable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) throws {
        let components = DateComponents(
            calendar: Self.calendar,
            timeZone: Self.timeZone,
            year: year,
            month: month,
            day: day
        )

        guard
            let date = Self.calendar.date(from: components),
            Self.calendar.dateComponents([.year, .month, .day], from: date)
                == DateComponents(year: year, month: month, day: day)
        else {
            throw SimulationTimeError.invalidDate(year: year, month: month, day: day)
        }

        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public func adding(days: Int) throws -> Self {
        guard let result = Self.calendar.date(byAdding: .day, value: days, to: foundationDate) else {
            throw SimulationTimeError.dateArithmeticFailed
        }
        return try Self(date: result)
    }

    public func days(until other: Self) -> Int {
        Self.calendar.dateComponents([.day], from: foundationDate, to: other.foundationDate).day ?? 0
    }

    private init(date: Date) throws {
        let components = Self.calendar.dateComponents([.year, .month, .day], from: date)
        guard
            let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            throw SimulationTimeError.dateArithmeticFailed
        }
        try self.init(year: year, month: month, day: day)
    }

    private var foundationDate: Date {
        Self.calendar.date(
            from: DateComponents(
                calendar: Self.calendar,
                timeZone: Self.timeZone,
                year: year,
                month: month,
                day: day
            )
        )!
    }

    private static let timeZone = TimeZone(secondsFromGMT: 0)!
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}

public enum SimulationTimeError: Error, Equatable, Sendable {
    case invalidDate(year: Int, month: Int, day: Int)
    case negativeAdvance(Int)
    case cannotReverse(from: SimulationDate, to: SimulationDate)
    case dateArithmeticFailed
}

/// The single source of truth for elapsed simulation time.
public struct SimulationClock: Codable, Hashable, Sendable {
    public private(set) var currentDate: SimulationDate
    public private(set) var elapsedDays: Int

    public init(startingOn date: SimulationDate) {
        currentDate = date
        elapsedDays = 0
    }

    @discardableResult
    public mutating func advance(by days: Int = 1) throws -> SimulationDate {
        guard days >= 0 else {
            throw SimulationTimeError.negativeAdvance(days)
        }
        currentDate = try currentDate.adding(days: days)
        elapsedDays += days
        return currentDate
    }

    @discardableResult
    public mutating func advance(to date: SimulationDate) throws -> SimulationDate {
        guard date >= currentDate else {
            throw SimulationTimeError.cannotReverse(from: currentDate, to: date)
        }
        return try advance(by: currentDate.days(until: date))
    }
}

public struct PersonID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        self.rawValue = value
    }
}

public struct PersonName: Codable, Hashable, Sendable {
    public let given: String
    public let family: String

    public init(given: String, family: String) throws {
        let given = given.trimmingCharacters(in: .whitespacesAndNewlines)
        let family = family.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !given.isEmpty, !family.isEmpty else {
            throw PersonError.incompleteName
        }
        self.given = given
        self.family = family
    }

    public var full: String {
        "\(given) \(family)"
    }
}

public enum LifeStage: String, Codable, CaseIterable, Sendable {
    case childhood
    case adolescence
    case adulthood
    case laterLife
}

public enum PersonError: Error, Equatable, Sendable {
    case incompleteName
    case datePrecedesBirth(reference: SimulationDate, birth: SimulationDate)
}

/// A stable human identity whose age is derived from the simulation clock.
public struct Person: Identifiable, Codable, Hashable, Sendable {
    public let id: PersonID
    public var name: PersonName
    public let dateOfBirth: SimulationDate

    public init(id: PersonID, name: PersonName, dateOfBirth: SimulationDate) {
        self.id = id
        self.name = name
        self.dateOfBirth = dateOfBirth
    }

    public func age(on date: SimulationDate) throws -> Int {
        guard date >= dateOfBirth else {
            throw PersonError.datePrecedesBirth(reference: date, birth: dateOfBirth)
        }

        let birthdayHasOccurred =
            (date.month, date.day) >= (dateOfBirth.month, dateOfBirth.day)
        return date.year - dateOfBirth.year - (birthdayHasOccurred ? 0 : 1)
    }

    public func lifeStage(on date: SimulationDate) throws -> LifeStage {
        switch try age(on: date) {
        case 0...12:
            return .childhood
        case 13...17:
            return .adolescence
        case 18...64:
            return .adulthood
        default:
            return .laterLife
        }
    }
}

public enum NewLifeError: Error, Equatable, Sendable {
    case startsBeforeBirth(start: SimulationDate, birth: SimulationDate)
}

/// The player-selected facts required to begin a life.
///
/// Date of birth is captured as a complete calendar date. Age is deliberately
/// omitted because it is derived from that date and the simulation clock.
public struct NewLifeDraft: Codable, Hashable, Sendable {
    public let personID: PersonID
    public var name: PersonName
    public let dateOfBirth: SimulationDate
    public let startingDate: SimulationDate

    public init(
        personID: PersonID,
        name: PersonName,
        dateOfBirth: SimulationDate,
        startingDate: SimulationDate
    ) {
        self.personID = personID
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.startingDate = startingDate
    }

    public func create() throws -> NewLife {
        guard startingDate >= dateOfBirth else {
            throw NewLifeError.startsBeforeBirth(
                start: startingDate,
                birth: dateOfBirth
            )
        }

        return NewLife(
            protagonist: Person(
                id: personID,
                name: name,
                dateOfBirth: dateOfBirth
            ),
            clock: SimulationClock(startingOn: startingDate)
        )
    }
}

/// A newly-created playable life with one authoritative person and clock.
public struct NewLife: Codable, Hashable, Sendable {
    public let protagonist: Person
    public private(set) var clock: SimulationClock

    private enum CodingKeys: String, CodingKey {
        case protagonist
        case clock
    }

    fileprivate init(protagonist: Person, clock: SimulationClock) {
        self.protagonist = protagonist
        self.clock = clock
    }

    public var age: Int {
        let date = clock.currentDate
        let birth = protagonist.dateOfBirth
        let birthdayHasOccurred = (date.month, date.day) >= (birth.month, birth.day)
        return date.year - birth.year - (birthdayHasOccurred ? 0 : 1)
    }

    @discardableResult
    public mutating func advance(by days: Int = 1) throws -> SimulationDate {
        try clock.advance(by: days)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let protagonist = try container.decode(Person.self, forKey: .protagonist)
        let clock = try container.decode(SimulationClock.self, forKey: .clock)

        guard clock.currentDate >= protagonist.dateOfBirth else {
            throw DecodingError.dataCorruptedError(
                forKey: .clock,
                in: container,
                debugDescription: "A new life's clock cannot precede its date of birth."
            )
        }

        self.protagonist = protagonist
        self.clock = clock
    }
}
